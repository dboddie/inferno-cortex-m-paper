.\" Disable page numbers in the ms macros.
.ds CH
.nr PS 9
.\" .fam LUXS
.ps 11
.ce 9999
.B "Three More Cortex-M Inferno Ports"
.br
.ps 9
.sp 9p
.I "David Boddie"
.I "david@boddie.org.uk"
.sp 12p
.ce
ABSTRACT
.sp 10p
.in 0.5i
.ll 5.5i
Starting from a port of Inferno to a single microcontroller, work is ongoing to
extend support to a wider group of microcontrollers and small systems based on
ARM Cortex-M4 and Cortex-M7 cores.

.sp 4p
.SH
Introduction
.LP
A port of Inferno to the STM32F405 [1] microcontroller has been available for
over a year. During this time, the work done to create the port has been applied
to three other related microcontrollers, first reusing common code, and finally
merging most of the ports into one source tree.

The STM32F405 microcontroller is based on an ARM Cortex-M4 core. This type of
core provides a basic level of features that make code written for it applicable
to Cortex-M7 cores without too much adjustment. It is unclear how much code
could be reused to support related cores, such as the Cortex-M0+, which is used
by the RP2040 microcontroller. However, that microcontroller is already supported
by the Raspberry Pi Pico port [2].

The descriptions that follow briefly cover some implementation issues that affect
ports to systems based on Cortex-M4 and Cortex-M7 cores. It may be useful to
consult the Wikipedia article [3] about ARM Cortex-M cores to learn more about
the similarities and differences between them.
.
.SH
Toolchain
.LP
The existing ports of Inferno to ARM systems relied on the availability of a
regular 32-bit instruction set. In contrast, Cortex-M4 cores only provide
support for Thumb and Thumb-2 instructions, making the use of a different
toolchain necessary: a combination of
.CW "tc",
.CW "5a"
and
.CW "tl".

Of these tools,
.CW "tc"
and
.CW "tl"
were modified to add support for the floating point instruction set used by
Cortex-M4 cores with the appropriate extension. Additionally,
.CW "tl"
was adjusted to re-enable existing support for compiling string constants into
the text section of a binary. Depending on the configuration and tools used
to build an Inferno system, this can lead to a substantial reduction in RAM
usage at run-time.
.
.SH
Task switching
.LP
Cortex-M4 cores differ from traditional ARM cores in both the instruction sets
used and in the available processor modes. This means that some techniques used
by many existing ports of Inferno to ARM systems are not applicable to these
cores. The way that task switching is performed is one area that needed revising
to fit a different processing model.

Existing ports relied on the ability of the processor to switch between the
processor modes during exception handling, and used this ability to implement
a mechanism for task switching that could ensure that
.CW "setlabel"
and
.CW "gotolabel"
calls were always called in the same processor mode.

On Cortex-M4 cores, exceptions cause the processor to enter a Handler mode that
it can only leave by returning from the exception back to the interrupted code.
While it is possible to perform task switching while running in this mode, the
task switching mechanism also needs to be able to run in the normal Thread mode.
As a result, a different mechanism is used to ensure that Thread mode is always
used when performing task switching.

.SH
Floating point support
.LP
Cortex-M4 cores tend to provide some level of hardware floating point arithmetic
support, and this is the case with the STM32F405 microcontroller. The existing
code in ports such as the Raspberry Pi port [4] was useful in terms of providing
a framework for supporting floating point instructions, but required adjustment
to work with the floating point instructions supported by the newer cores.

Use of a floating point emulator is necessary for Cortex-M4 cores because they
only tend to support single precision arithmetic, making it necessary to trap
instructions that operate on double precision values.
Many existing ports tended to rely completely on an emulator to handle all
floating point instructions when an undefined instruction exception occurs.
This maintains a set of emulated floating point registers associated with each
process. However, since we want to take advantage of the hardware support for
floating point, an approach that maintains the actual registers is used.
This relies on the modification of stacked floating point registers during
exceptions.

One simplification made to the floating point emulator is to only use it to
handle one undefined instruction at a time instead of trying to handle as many
consecutive instructions as possible. Since supported and unsupported
instructions may be mixed together, the additional work of opportunistically
checking for consecutive instructions is time that could be spent letting the
hardware either execute them or raise another exception.

One disadvantage to this kind of partial emulation solution is the additional
overhead it places on the stack for the kernel and each process, as space for
a full set of floating point registers is reserved on the stack when an
exception occurs. A pure software solution might prove to be sufficient if use
of hardware floating point support doesn't provide substantially faster
floating point arithmetic performance.

It should be noted that Cortex-M7 cores can be provided with double precision
floating point units. For these, either minimal or no emulation is needed.
.
.SH
Memory savings
.LP
As described in the previous work [5], some effort was needed to reduce the
amount of RAM used by Limbo modules on a running system. This was achieved
by expanding the code sections of Dis files during compilation of an Inferno
system and running them from flash memory.

It was observed that the freezing process had the effect of moving much of
the root file system from the data section to the text section of the binary.
This has the effect of reducing the initial RAM overhead of the system.
To take advantage of this feature for general use, the
.CW "data2texts"
utility was created to replace the existing
.CW "data2s"
utility which normally translates binary data into assembly language
.CW "DATA"
structures for compilation into the system. This variant simply uses
.CW "TEXT"
directives instead, enabling the data to be stored alongside kernel code.

Additional savings to the initial RAM footprint of the system are obtained
by passing the
.CW "-t"
option with the
.CW "tl"
loader. This has the effect of placing string constants in the text section
of the binary, again reducing the amount of data copied into RAM.

For a system including non-frozen Limbo modules, the following table shows
the effect of using
.CW "data2texts"
instead of
.CW "data2s"
to encode data, and the larger effect of including string constants in the
text section of the binary for a microcontroller with 384K of RAM.

.TS
center tab(:);
  c      cf(I) s cf(I) s
  c     | c   s | c   s |
  c     | cf(B) | cf(B) | cf(B) | cf(B) |
| cf(B) | c     | c     | c     | c     |.
:Data strings:Text strings
:_:_
:data2s:data2texts:data2s:data2texts
_
kernel:477272:477272:477272:477272
_
maxsize:165120:324608:339712:339968
_
hw:132832:132832:132832:132832
_
.TE

The
.B "kernel"
row shows the size of the system binary in bytes, which is not affected by the
changes. The
.B "maxsize"
and
.B "hw"
rows show the corresponding values in bytes from
.CW "/dev/memory",
indicating the amount of RAM available to the system and the allocation high
water mark after running the .CW "ls"
utility. As mentioned, using the
.CW "data2texts"
utility provides a memory saving that is largely overshadowed by the effect
of compiling string constants into the kernel text. Since there is an overlap
in these approaches, the combination of them yields only a marginal additional
memory saving.

A system containing frozen Limbo modules shows much the same effect.

.TS
center tab(:);
  c      cf(I) s cf(I) s
  c     | c   s | c   s |
  c     | cf(B) | cf(B) | cf(B) | cf(B) |
| cf(B) | c     | c     | c     | c     |.
:Data strings:Text strings
:_:_
:data2s:data2texts:data2s:data2texts
_
kernel:614584:614608:614584:614608
_
maxsize:309504:324608:339712:339968
_
hw:94048:94048:94048:94048
_
.TE

.
.SH
New platforms
.LP

SAMD51, Apollo3, 
Combined tree.

.SH
Conclusion and future work
.LP


The source code associated with this work can be found in the following repository:
.br
.I https://github.com/dboddie/inferno-os/tree/cortexm

.SH
References
.IP 1.
David Boddie, ``STM32F405 Port of Inferno'',
.br
.I https://github.com/dboddie/inferno-os/tree/stm32f405
.
.IP 2.
Caerwyn Jones,
``Raspberry Pi Pico Port of Inferno'',
.br
.I https://github.com/caerwynj/inferno-os/tree/pico
.
.IP 3.
Wikipedia, ``ARM Cortex-M'',
.I https://en.wikipedia.org/wiki/ARM_Cortex-M
.
.IP 4.
Lynxline,
``Porting Inferno OS to Raspberry Pi'',
.br
http://lynxline.com/porting-inferno-os-to-raspberry-pi/
.
.IP 5.
David Boddie, ``Hell Freezes Over: Freezing Limbo modules to reduce
Inferno's memory footprint'',
.I "9\*{th\*} International Workshop on Plan 9" ,
Waterloo, Canada, 2023
.br
.I https://9e.iwp9.org/
.
.IP 6.
