# JEnt

A hardware Random Number Generator (RNG) based on CPU timing jitter.

This is a rewrite of the [jitterentropy-library](https://github.com/smuellerDD/jitterentropy-library) by 
[Stephan Mueller (smuellerDD)](https://github.com/smuellerDD) in [Zig](https://ziglang.org/).

From the original repository:
```
The Jitter RNG provides a noise source using the CPU execution timing jitter. 
It does not depend on any system resource other than a high-resolution time stamp. 
It is a small-scale, yet fast entropy source that is viable in almost all 
environments and on a lot of CPU architectures.

The implementation of the Jitter RNG is independent of any operating system. 
As such, it could even run on baremetal without any operating system.

The design of the RNG is given in the documentation found in at 
http://www.chronox.de/jent.html . This documentation also covers the full 
assessment of the SP800-90B compliance as well as all required test code.

---

Copyright (C) 2017 - 2022, Stephan Mueller <smueller@chronox.de>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, and the entire permission notice in its entirety,
   including the disclaimer of warranties.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote
   products derived from this software without specific prior
   written permission.

ALTERNATIVELY, this product may be distributed under the terms of
the GNU General Public License, in which case the provisions of the GPL2
are required INSTEAD OF the above restrictions.  (This clause is
necessary due to a potential bad interaction between the GPL and
the restrictions contained in a BSD-style copyright.)

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ALL OF
WHICH ARE HEREBY DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF NOT ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
```