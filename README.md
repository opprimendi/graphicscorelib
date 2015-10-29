Adobe graphics core lib [![Build Status](https://travis-ci.org/opprimendi/graphicscorelib.svg)](https://travis-ci.orgopprimendi/graphicscorelib)
==================================================

A Flash Platform SDK, a nice toolbox with libs for every ActionScript 3 developer.

THIS SDK IS IN VERY EARLY DEVELOPMENT

Current work items:
- organize; move things out of top level packages. Add testing directories.
- test framework for all tests.

Current Projects:

AGALMiniAssembler
	The Mini assembler generates AGAL byte code from a simple
	source text language. AGAL byte code is required for Molehill,
	the Flash 3D API. The MiniAssembler is a run time assembler -
	it is an AS3 class that is a part of your 3D app.

AGALMiniAssembler
	The Mini assembler for Stage3D extended profile.

AGALMacroAssembler
	The Macro assembler extends the Mini assembler with macros (similar
	to functions), basic math expressions, aliases, and constant allocation.

	Status: Alpha, initial testing (not yet uploaded)
	Test suite: TBD

FractalGeometryGenerator
	TBD

PerspectiveMatrix3D
	A class for creating perspective matrices, for use in 3D applications.

	Status: Beta, in use by early adopters
	Test suite: TBD
	
Sprite3D
	A Sprite layer on top of the Molehill APIs (Stage3D).
	
	Status: Beta, in use by early adopters
	Test suite: TBD

Copyright (c) 2011, Adobe Systems Incorporated
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution.

* Neither the name of Adobe Systems Incorporated nor the names of its 
contributors may be used to endorse or promote products derived from 
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
