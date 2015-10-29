/*
   Copyright (c) 2015, Adobe Systems Incorporated
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
 */
package com.adobe.utils.v3
{
	import flash.display3D.*;
	import flash.utils.*;
	
	public class AGALMiniAssembler
	{
		protected static const REGEXP_OUTER_SPACES:RegExp = /^\s+|\s+$/g;
		protected static const REGEXP_LINES:RegExp = /[\f\n\r\v]+/g;
		protected static const REGEXP_OPTSI:RegExp = /<.*>/g;
		protected static const REGEXP_OPTS:RegExp = /([\w\.\-\+]+)/gi;
		protected static const REGEXP_OPCODE:RegExp = /^\w{3}/ig;
		protected static const REGEXP_REGS:RegExp = /vc\[([vof][acostdip]?)(\d*)?(\.[xyzw](\+\d{1,3})?)?\](\.[xyzw]{1,4})?|([vof][acostdip]?)(\d*)?(\.[xyzw]{1,4})?/gi;
		protected static const REGEXP_RELREG:RegExp = /\[.*\]/ig;
		protected static const REGEXP_RES:RegExp = /^\b[A-Za-z]{1,2}/ig;
		protected static const REGEXP_IDX:RegExp = /\d+/;
		protected static const REGEXP_MASK:RegExp = /(\.[xyzw]{1,4})/;
		protected static const REGEXP_RELNAME:RegExp = /[A-Za-z]{1,2}/ig;
		protected static const REGEXP_SEL:RegExp = /(\.[xyzw]{1,1})/;
		protected static const REGEXP_RELOFS:RegExp = /\+\d{1,3}/ig;
		
		private var debugEnabled:Boolean = false;
		
		private static var initialized:Boolean = false;
		public var verbose:Boolean = false;
		
		private var _error:String = "";
		public function get error():String { return _error; }
		
		private var _agalcode:ByteArray = null;
		public function get agalcode():ByteArray { return _agalcode; }
		
		public function AGALMiniAssembler(debugging:Boolean = false):void
		{
			debugEnabled = debugging;
			if (!initialized)
				init();
		}
		
		public function assemble2(ctx3d:Context3D, version:uint, vertexsrc:String, fragmentsrc:String):Program3D
		{
			var agalvertex:ByteArray = assemble(VERTEX, vertexsrc, version);
			var agalfragment:ByteArray = assemble(FRAGMENT, fragmentsrc, version);
			var prog:Program3D = ctx3d.createProgram();
			prog.upload(agalvertex, agalfragment);
			return prog;
		}
		
		public function assemble(mode:String, source:String, version:uint = 1, ignorelimits:Boolean = false):ByteArray
		{
			var start:int = verbose ? getTimer() : 0;
			
			_agalcode = new ByteArray();
			_error = "";
			
			var isFrag:Boolean = false;
			
			if (mode == FRAGMENT)
				isFrag = true;
			else if (mode != VERTEX)
				_error = 'ERROR: mode needs to be "' + FRAGMENT + '" or "' + VERTEX + '" but is "' + mode + '".';
			
			agalcode.endian = Endian.LITTLE_ENDIAN;
			agalcode.writeByte(0xa0);				// tag version
			agalcode.writeUnsignedInt(version);		// AGAL version, big endian, bit pattern will be 0x01000000
			agalcode.writeByte(0xa1);				// tag program id
			agalcode.writeByte(isFrag ? 1 : 0);	// vertex or fragment
			
			initregmap(version, ignorelimits);
			
			var lines:Array = source.replace(REGEXP_LINES, "\n").split("\n");
			var nest:int = 0;
			var nops:int = 0;
			var i:int;
			var lng:int = lines.length;
			
			for (i = 0; i < lng && _error == ""; i++)
			{
				var line:String = lines[i].replace(REGEXP_OUTER_SPACES, "");
				
				// remove comments
				var startcomment:int = line.search("//");
				if (startcomment != -1)
					line = line.slice(0, startcomment);
				
				// grab options
				var optsi:int = line.search(REGEXP_OPTSI);
				var opts:Array;
				if (optsi != -1)
				{
					opts = line.slice(optsi).match(REGEXP_OPTS);
					line = line.slice(0, optsi);
				}
				
				// find opcode
				var opCode:Array = line.match(REGEXP_OPCODE);
				if (!opCode)
				{
					if (line.length >= 3)
						trace("warning: bad line " + i + ": " + lines[i]);
					continue;
				}
				var opFound:OpCode = OPMAP[opCode[0]];
				
				// if debug is enabled, output the opcodes
				if (debugEnabled)
					trace(opFound);
				
				if (opFound == null)
				{
					if (line.length >= 3)
						trace("warning: bad line " + i + ": " + lines[i]);
					continue;
				}
				
				line = line.slice(line.search(opFound.name) + opFound.name.length);
				
				if ((opFound.flags & OP_VERSION2) && version < 2)
				{
					_error = "error: opcode requires version 2.";
					break;
				}
				
				if ((opFound.flags & OP_VERT_ONLY) && isFrag)
				{
					_error = "error: opcode is only allowed in vertex programs.";
					break;
				}
				
				if ((opFound.flags & OP_FRAG_ONLY) && !isFrag)
				{
					_error = "error: opcode is only allowed in fragment programs.";
					break;
				}
				if (verbose)
					trace("emit opcode=" + opFound);
				
				agalcode.writeUnsignedInt(opFound.emitCode);
				nops++;
				
				if (nops > MAX_OPCODES)
				{
					_error = "error: too many opcodes. maximum is " + MAX_OPCODES + ".";
					break;
				}
				
				// get operands, use regexp
				var regs:Array;
				
				// will match both syntax
				regs = line.match(REGEXP_REGS);
				
				if (!regs || regs.length != opFound.numRegister)
				{
					_error = "error: wrong number of operands. found " + regs.length + " but expected " + opFound.numRegister + ".";
					break;
				}
				
				var badreg:Boolean = false;
				var pad:uint = 64 + 64 + 32;
				var regLength:uint = regs.length;
				
				for (var j:int = 0; j < regLength; j++)
				{
					var isRelative:Boolean = false;
					var relreg:Array = regs[j].match(REGEXP_RELREG);
					if (relreg && relreg.length > 0)
					{
						regs[j] = regs[j].replace(relreg[0], "0");
						
						if (verbose)
							trace("IS REL");
						isRelative = true;
					}
					
					var res:Array = regs[j].match(REGEXP_RES);
					if (!res)
					{
						_error = "error: could not parse operand " + j + " (" + regs[j] + ").";
						badreg = true;
						break;
					}
					var regFound:Register = REGMAP[res[0]];
					
					// if debug is enabled, output the registers
					if (debugEnabled)
						trace(regFound);
					
					if (regFound == null)
					{
						_error = "error: could not find register name for operand " + j + " (" + regs[j] + ").";
						badreg = true;
						break;
					}
					
					if (isFrag)
					{
						if (!(regFound.flags & REG_FRAG))
						{
							_error = "error: register operand " + j + " (" + regs[j] + ") only allowed in vertex programs.";
							badreg = true;
							break;
						}
						if (isRelative)
						{
							_error = "error: register operand " + j + " (" + regs[j] + ") relative adressing not allowed in fragment programs.";
							badreg = true;
							break;
						}
					}
					else
					{
						if (!(regFound.flags & REG_VERT))
						{
							_error = "error: register operand " + j + " (" + regs[j] + ") only allowed in fragment programs.";
							badreg = true;
							break;
						}
					}
					
					regs[j] = regs[j].slice(regs[j].search(regFound.name) + regFound.name.length);
					//trace( "REGNUM: " +regs[j] );
					var idxmatch:Array = isRelative ? relreg[0].match(REGEXP_IDX) : regs[j].match(REGEXP_IDX);
					var regidx:uint = 0;
					
					if (idxmatch)
						regidx = uint(idxmatch[0]);
					
					if (regFound.range < regidx)
					{
						_error = "error: register operand " + j + " (" + regs[j] + ") index exceeds limit of " + (regFound.range + 1) + ".";
						badreg = true;
						break;
					}
					
					var regmask:uint = 0;
					var maskmatch:Array = regs[j].match(REGEXP_MASK);
					var isDest:Boolean = (j == 0 && !(opFound.flags & OP_NO_DEST));
					var isSampler:Boolean = (j == 2 && (opFound.flags & OP_SPECIAL_TEX));
					var reltype:uint = 0;
					var relsel:uint = 0;
					var reloffset:int = 0;
					
					if (isDest && isRelative)
					{
						_error = "error: relative can not be destination";
						badreg = true;
						break;
					}
					
					if (maskmatch)
					{
						regmask = 0;
						var cv:uint;
						var maskLength:uint = maskmatch[0].length;
						for (var k:int = 1; k < maskLength; k++)
						{
							cv = maskmatch[0].charCodeAt(k) - "x".charCodeAt(0);
							if (cv > 2)
								cv = 3;
							if (isDest)
								regmask |= 1 << cv;
							else
								regmask |= cv << ((k - 1) << 1);
						}
						if (!isDest)
							for (; k <= 4; k++)
								regmask |= cv << ((k - 1) << 1); // repeat last								
					}
					else
					{
						regmask = isDest ? 0xf : 0xe4; // id swizzle or mask						
					}
					
					if (isRelative)
					{
						var relname:Array = relreg[0].match(REGEXP_RELNAME);
						var regFoundRel:Register = REGMAP[relname[0]];
						if (regFoundRel == null)
						{
							_error = "error: bad index register";
							badreg = true;
							break;
						}
						reltype = regFoundRel.emitCode;
						var selmatch:Array = relreg[0].match(REGEXP_SEL);
						if (selmatch.length == 0)
						{
							_error = "error: bad index register select";
							badreg = true;
							break;
						}
						relsel = selmatch[0].charCodeAt(1) - "x".charCodeAt(0);
						if (relsel > 2)
							relsel = 3;
						var relofs:Array = relreg[0].match(REGEXP_RELOFS);
						if (relofs.length > 0)
							reloffset = relofs[0];
						if (reloffset < 0 || reloffset > 255)
						{
							_error = "error: index offset " + reloffset + " out of bounds. [0..255]";
							badreg = true;
							break;
						}
						if (verbose)
							trace("RELATIVE: type=" + reltype + "==" + relname[0] + " sel=" + relsel + "==" + selmatch[0] + " idx=" + regidx + " offset=" + reloffset);
					}
					
					if (verbose)
						trace("  emit argcode=" + regFound + "[" + regidx + "][" + regmask + "]");
					if (isDest)
					{
						agalcode.writeShort(regidx);
						agalcode.writeByte(regmask);
						agalcode.writeByte(regFound.emitCode);
						pad -= 32;
					}
					else
					{
						if (isSampler)
						{
							if (verbose)
								trace("  emit sampler");
							var samplerbits:uint = 5; // type 5 
							var optsLength:uint = opts == null ? 0 : opts.length;
							var bias:Number = 0;
							for (k = 0; k < optsLength; k++)
							{
								if (verbose)
									trace("    opt: " + opts[k]);
								var optfound:Sampler = SAMPLEMAP[opts[k]];
								if (optfound == null)
								{
									// todo check that it's a number...
									//trace( "Warning, unknown sampler option: "+opts[k] );
									bias = Number(opts[k]);
									if (verbose)
										trace("    bias: " + bias);
								}
								else
								{
									if (optfound.flag != SAMPLER_SPECIAL_SHIFT)
										samplerbits &= ~(0xf << optfound.flag);
									samplerbits |= optfound.mask << optfound.flag;
								}
							}
							agalcode.writeShort(regidx);
							agalcode.writeByte(int(bias * 8));
							agalcode.writeByte(0);
							agalcode.writeUnsignedInt(samplerbits);
							
							if (verbose)
								trace("    bits: " + (samplerbits - 5));
							pad -= 64;
						}
						else
						{
							if (j == 0)
							{
								agalcode.writeUnsignedInt(0);
								pad -= 32;
							}
							agalcode.writeShort(regidx);
							agalcode.writeByte(reloffset);
							agalcode.writeByte(regmask);
							agalcode.writeByte(regFound.emitCode);
							agalcode.writeByte(reltype);
							agalcode.writeShort(isRelative ? (relsel | (1 << 15)) : 0);
							
							pad -= 64;
						}
					}
				}
				
				// pad unused regs
				for (j = 0; j < pad; j += 8)
					agalcode.writeByte(0);
				
				if (badreg)
					break;
			}
			
			if (_error != "")
			{
				_error += "\n  at line " + i + " " + lines[i];
				agalcode.length = 0;
				trace(_error);
			}
			
			// trace the bytecode bytes if debugging is enabled
			if (debugEnabled)
			{
				var dbgLine:String = "generated bytecode:";
				var agalLength:uint = agalcode.length;
				for (var index:uint = 0; index < agalLength; index++)
				{
					if (!(index % 16))
						dbgLine += "\n";
					if (!(index % 4))
						dbgLine += " ";
					
					var byteStr:String = agalcode[index].toString(16);
					if (byteStr.length < 2)
						byteStr = "0" + byteStr;
					
					dbgLine += byteStr;
				}
				trace(dbgLine);
			}
			
			if (verbose)
				trace("AGALMiniAssembler.assemble time: " + ((getTimer() - start) / 1000) + "s");
			
			return agalcode;
		}
		
		private function initregmap(version:uint, ignorelimits:Boolean):void
		{
			// version changes limits				
			REGMAP[VA] = new Register(VA, "vertex attribute", 0x0, ignorelimits ? 1024 : ((version == 1 || version == 2) ? 7 : 15), REG_VERT | REG_READ);
			REGMAP[VC] = new Register(VC, "vertex constant", 0x1, ignorelimits ? 1024 : (version == 1 ? 127 : 249), REG_VERT | REG_READ);
			REGMAP[VT] = new Register(VT, "vertex temporary", 0x2, ignorelimits ? 1024 : (version == 1 ? 7 : 25), REG_VERT | REG_WRITE | REG_READ);
			REGMAP[VO] = new Register(VO, "vertex output", 0x3, ignorelimits ? 1024 : 0, REG_VERT | REG_WRITE);
			REGMAP[VI] = new Register(VI, "varying", 0x4, ignorelimits ? 1024 : (version == 1 ? 7 : 9), REG_VERT | REG_FRAG | REG_READ | REG_WRITE);
			REGMAP[FC] = new Register(FC, "fragment constant", 0x1, ignorelimits ? 1024 : (version == 1 ? 27 : ((version == 2) ? 63 : 199)), REG_FRAG | REG_READ);
			REGMAP[FT] = new Register(FT, "fragment temporary", 0x2, ignorelimits ? 1024 : (version == 1 ? 7 : 25), REG_FRAG | REG_WRITE | REG_READ);
			REGMAP[FS] = new Register(FS, "texture sampler", 0x5, ignorelimits ? 1024 : 7, REG_FRAG | REG_READ);
			REGMAP[FO] = new Register(FO, "fragment output", 0x3, ignorelimits ? 1024 : (version == 1 ? 0 : 3), REG_FRAG | REG_WRITE);
			REGMAP[FD] = new Register(FD, "fragment depth output", 0x6, ignorelimits ? 1024 : (version == 1 ? -1 : 0), REG_FRAG | REG_WRITE);
			
			// aliases
			REGMAP["op"] = REGMAP[VO];
			REGMAP["i"] = REGMAP[VI];
			REGMAP["v"] = REGMAP[VI];
			REGMAP["oc"] = REGMAP[FO];
			REGMAP["od"] = REGMAP[FD];
			REGMAP["fi"] = REGMAP[VI];
		}
		
		static private function init():void
		{
			initialized = true;
			
			// Fill the dictionaries with opcodes and registers
			OPMAP[MOV] = new OpCode(MOV, 2, 0x00, 0);
			OPMAP[ADD] = new OpCode(ADD, 3, 0x01, 0);
			OPMAP[SUB] = new OpCode(SUB, 3, 0x02, 0);
			OPMAP[MUL] = new OpCode(MUL, 3, 0x03, 0);
			OPMAP[DIV] = new OpCode(DIV, 3, 0x04, 0);
			OPMAP[RCP] = new OpCode(RCP, 2, 0x05, 0);
			OPMAP[MIN] = new OpCode(MIN, 3, 0x06, 0);
			OPMAP[MAX] = new OpCode(MAX, 3, 0x07, 0);
			OPMAP[FRC] = new OpCode(FRC, 2, 0x08, 0);
			OPMAP[SQT] = new OpCode(SQT, 2, 0x09, 0);
			OPMAP[RSQ] = new OpCode(RSQ, 2, 0x0a, 0);
			OPMAP[POW] = new OpCode(POW, 3, 0x0b, 0);
			OPMAP[LOG] = new OpCode(LOG, 2, 0x0c, 0);
			OPMAP[EXP] = new OpCode(EXP, 2, 0x0d, 0);
			OPMAP[NRM] = new OpCode(NRM, 2, 0x0e, 0);
			OPMAP[SIN] = new OpCode(SIN, 2, 0x0f, 0);
			OPMAP[COS] = new OpCode(COS, 2, 0x10, 0);
			OPMAP[CRS] = new OpCode(CRS, 3, 0x11, 0);
			OPMAP[DP3] = new OpCode(DP3, 3, 0x12, 0);
			OPMAP[DP4] = new OpCode(DP4, 3, 0x13, 0);
			OPMAP[ABS] = new OpCode(ABS, 2, 0x14, 0);
			OPMAP[NEG] = new OpCode(NEG, 2, 0x15, 0);
			OPMAP[SAT] = new OpCode(SAT, 2, 0x16, 0);
			OPMAP[M33] = new OpCode(M33, 3, 0x17, OP_SPECIAL_MATRIX);
			OPMAP[M44] = new OpCode(M44, 3, 0x18, OP_SPECIAL_MATRIX);
			OPMAP[M34] = new OpCode(M34, 3, 0x19, OP_SPECIAL_MATRIX);
			OPMAP[DDX] = new OpCode(DDX, 2, 0x1a, OP_VERSION2 | OP_FRAG_ONLY);
			OPMAP[DDY] = new OpCode(DDY, 2, 0x1b, OP_VERSION2 | OP_FRAG_ONLY);
			OPMAP[IFE] = new OpCode(IFE, 2, 0x1c, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR);
			OPMAP[INE] = new OpCode(INE, 2, 0x1d, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR);
			OPMAP[IFG] = new OpCode(IFG, 2, 0x1e, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR);
			OPMAP[IFL] = new OpCode(IFL, 2, 0x1f, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR);
			OPMAP[ELS] = new OpCode(ELS, 0, 0x20, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_DECNEST | OP_SCALAR);
			OPMAP[EIF] = new OpCode(EIF, 0, 0x21, OP_NO_DEST | OP_VERSION2 | OP_DECNEST | OP_SCALAR);
			// space			
			//OPMAP[ TED ] = new OpCode( TED, 3, 0x26, OP_FRAG_ONLY | OP_SPECIAL_TEX | OP_VERSION2);	//ted is not available in AGAL2		
			OPMAP[KIL] = new OpCode(KIL, 1, 0x27, OP_NO_DEST | OP_FRAG_ONLY);
			OPMAP[TEX] = new OpCode(TEX, 3, 0x28, OP_FRAG_ONLY | OP_SPECIAL_TEX);
			OPMAP[SGE] = new OpCode(SGE, 3, 0x29, 0);
			OPMAP[SLT] = new OpCode(SLT, 3, 0x2a, 0);
			OPMAP[SGN] = new OpCode(SGN, 2, 0x2b, 0);
			OPMAP[SEQ] = new OpCode(SEQ, 3, 0x2c, 0);
			OPMAP[SNE] = new OpCode(SNE, 3, 0x2d, 0);
			
			SAMPLEMAP[RGBA] = new Sampler(RGBA, SAMPLER_TYPE_SHIFT, 0);
			SAMPLEMAP[COMPRESSED] = new Sampler(COMPRESSED, SAMPLER_TYPE_SHIFT, 1);
			SAMPLEMAP[COMPRESSEDALPHA] = new Sampler(COMPRESSEDALPHA, SAMPLER_TYPE_SHIFT, 2);
			SAMPLEMAP[DXT1] = new Sampler(DXT1, SAMPLER_TYPE_SHIFT, 1);
			SAMPLEMAP[DXT5] = new Sampler(DXT5, SAMPLER_TYPE_SHIFT, 2);
			SAMPLEMAP[VIDEO] = new Sampler(VIDEO, SAMPLER_TYPE_SHIFT, 3);
			SAMPLEMAP[D2] = new Sampler(D2, SAMPLER_DIM_SHIFT, 0);
			SAMPLEMAP[D3] = new Sampler(D3, SAMPLER_DIM_SHIFT, 2);
			SAMPLEMAP[CUBE] = new Sampler(CUBE, SAMPLER_DIM_SHIFT, 1);
			SAMPLEMAP[MIPNEAREST] = new Sampler(MIPNEAREST, SAMPLER_MIPMAP_SHIFT, 1);
			SAMPLEMAP[MIPLINEAR] = new Sampler(MIPLINEAR, SAMPLER_MIPMAP_SHIFT, 2);
			SAMPLEMAP[MIPNONE] = new Sampler(MIPNONE, SAMPLER_MIPMAP_SHIFT, 0);
			SAMPLEMAP[NOMIP] = new Sampler(NOMIP, SAMPLER_MIPMAP_SHIFT, 0);
			SAMPLEMAP[NEAREST] = new Sampler(NEAREST, SAMPLER_FILTER_SHIFT, 0);
			SAMPLEMAP[LINEAR] = new Sampler(LINEAR, SAMPLER_FILTER_SHIFT, 1);
			SAMPLEMAP[ANISOTROPIC2X] = new Sampler(ANISOTROPIC2X, SAMPLER_FILTER_SHIFT, 2);
			SAMPLEMAP[ANISOTROPIC4X] = new Sampler(ANISOTROPIC4X, SAMPLER_FILTER_SHIFT, 3);
			SAMPLEMAP[ANISOTROPIC8X] = new Sampler(ANISOTROPIC8X, SAMPLER_FILTER_SHIFT, 4);
			SAMPLEMAP[ANISOTROPIC16X] = new Sampler(ANISOTROPIC16X, SAMPLER_FILTER_SHIFT, 5);
			SAMPLEMAP[CENTROID] = new Sampler(CENTROID, SAMPLER_SPECIAL_SHIFT, 1 << 0);
			SAMPLEMAP[SINGLE] = new Sampler(SINGLE, SAMPLER_SPECIAL_SHIFT, 1 << 1);
			SAMPLEMAP[IGNORESAMPLER] = new Sampler(IGNORESAMPLER, SAMPLER_SPECIAL_SHIFT, 1 << 2);
			SAMPLEMAP[REPEAT] = new Sampler(REPEAT, SAMPLER_REPEAT_SHIFT, 1);
			SAMPLEMAP[WRAP] = new Sampler(WRAP, SAMPLER_REPEAT_SHIFT, 1);
			SAMPLEMAP[CLAMP] = new Sampler(CLAMP, SAMPLER_REPEAT_SHIFT, 0);
			SAMPLEMAP[CLAMP_U_REPEAT_V] = new Sampler(CLAMP_U_REPEAT_V, SAMPLER_REPEAT_SHIFT, 2);
			SAMPLEMAP[REPEAT_U_CLAMP_V] = new Sampler(REPEAT_U_CLAMP_V, SAMPLER_REPEAT_SHIFT, 3);
		}
		
		private static const OPMAP:Dictionary = new Dictionary();
		private static const REGMAP:Dictionary = new Dictionary();
		private static const SAMPLEMAP:Dictionary = new Dictionary();
		
		private static const MAX_NESTING:int = 4;
		private static const MAX_OPCODES:int = 4096;
		
		private static const FRAGMENT:String = "fragment";
		private static const VERTEX:String = "vertex";
		
		// masks and shifts
		private static const SAMPLER_TYPE_SHIFT:uint = 8;
		private static const SAMPLER_DIM_SHIFT:uint = 12;
		private static const SAMPLER_SPECIAL_SHIFT:uint = 16;
		private static const SAMPLER_REPEAT_SHIFT:uint = 20;
		private static const SAMPLER_MIPMAP_SHIFT:uint = 24;
		private static const SAMPLER_FILTER_SHIFT:uint = 28;
		
		// regmap flags
		private static const REG_WRITE:uint = 0x1;
		private static const REG_READ:uint = 0x2;
		private static const REG_FRAG:uint = 0x20;
		private static const REG_VERT:uint = 0x40;
		
		// opmap flags
		private static const OP_SCALAR:uint = 0x1;
		private static const OP_SPECIAL_TEX:uint = 0x8;
		private static const OP_SPECIAL_MATRIX:uint = 0x10;
		private static const OP_FRAG_ONLY:uint = 0x20;
		private static const OP_VERT_ONLY:uint = 0x40;
		private static const OP_NO_DEST:uint = 0x80;
		private static const OP_VERSION2:uint = 0x100;
		private static const OP_INCNEST:uint = 0x200;
		private static const OP_DECNEST:uint = 0x400;
		
		// opcodes
		private static const MOV:String = "mov";
		private static const ADD:String = "add";
		private static const SUB:String = "sub";
		private static const MUL:String = "mul";
		private static const DIV:String = "div";
		private static const RCP:String = "rcp";
		private static const MIN:String = "min";
		private static const MAX:String = "max";
		private static const FRC:String = "frc";
		private static const SQT:String = "sqt";
		private static const RSQ:String = "rsq";
		private static const POW:String = "pow";
		private static const LOG:String = "log";
		private static const EXP:String = "exp";
		private static const NRM:String = "nrm";
		private static const SIN:String = "sin";
		private static const COS:String = "cos";
		private static const CRS:String = "crs";
		private static const DP3:String = "dp3";
		private static const DP4:String = "dp4";
		private static const ABS:String = "abs";
		private static const NEG:String = "neg";
		private static const SAT:String = "sat";
		private static const M33:String = "m33";
		private static const M44:String = "m44";
		private static const M34:String = "m34";
		private static const DDX:String = "ddx";
		private static const DDY:String = "ddy";
		private static const IFE:String = "ife";
		private static const INE:String = "ine";
		private static const IFG:String = "ifg";
		private static const IFL:String = "ifl";
		private static const ELS:String = "els";
		private static const EIF:String = "eif";
		private static const TED:String = "ted";
		private static const KIL:String = "kil";
		private static const TEX:String = "tex";
		private static const SGE:String = "sge";
		private static const SLT:String = "slt";
		private static const SGN:String = "sgn";
		private static const SEQ:String = "seq";
		private static const SNE:String = "sne";
		
		// registers
		private static const VA:String = "va";
		private static const VC:String = "vc";
		private static const VT:String = "vt";
		private static const VO:String = "vo";
		private static const VI:String = "vi";
		private static const FC:String = "fc";
		private static const FT:String = "ft";
		private static const FS:String = "fs";
		private static const FO:String = "fo";
		private static const FD:String = "fd";
		
		// samplers
		private static const D2:String = "2d";
		private static const D3:String = "3d";
		private static const CUBE:String = "cube";
		private static const MIPNEAREST:String = "mipnearest";
		private static const MIPLINEAR:String = "miplinear";
		private static const MIPNONE:String = "mipnone";
		private static const NOMIP:String = "nomip";
		private static const NEAREST:String = "nearest";
		private static const LINEAR:String = "linear";
		private static const ANISOTROPIC2X:String = "anisotropic2x"; //Introduced by Flash 14
		private static const ANISOTROPIC4X:String = "anisotropic4x"; //Introduced by Flash 14
		private static const ANISOTROPIC8X:String = "anisotropic8x"; //Introduced by Flash 14
		private static const ANISOTROPIC16X:String = "anisotropic16x"; //Introduced by Flash 14
		private static const CENTROID:String = "centroid";
		private static const SINGLE:String = "single";
		private static const IGNORESAMPLER:String = "ignoresampler";
		private static const REPEAT:String = "repeat";
		private static const WRAP:String = "wrap";
		private static const CLAMP:String = "clamp";
		private static const REPEAT_U_CLAMP_V:String = "repeat_u_clamp_v"; //Introduced by Flash 13
		private static const CLAMP_U_REPEAT_V:String = "clamp_u_repeat_v"; //Introduced by Flash 13
		private static const RGBA:String = "rgba";
		private static const COMPRESSED:String = "compressed";
		private static const COMPRESSEDALPHA:String = "compressedalpha";
		private static const DXT1:String = "dxt1";
		private static const DXT5:String = "dxt5";
		private static const VIDEO:String = "video";
	}
}

class OpCode
{
	public function OpCode(name:String, numRegister:uint, emitCode:uint, flags:uint)
	{
		this.name = name;
		this.numRegister = numRegister;
		this.emitCode = emitCode;
		this.flags = flags;
	}
	
	public var name:String;
	public var numRegister:uint;
	public var emitCode:uint;
	public var flags:uint;
	
	public function toString():String
	{
		return "[OpCode name=\"" + name + "\", numRegister=" + numRegister + ", emitCode=" + emitCode + ", flags=" + flags + "]";
	}
}

class Register
{
	public function Register(name:String, longName:String, emitCode:uint, range:uint, flags:uint)
	{
		this.name = name;
		this.longName = longName;
		this.emitCode = emitCode;
		this.range = range;
		this.flags = flags;
	}
	
	public var name:String;
	public var longName:String;
	public var emitCode:uint;
	public var range:uint;
	public var flags:uint;
	
	public function toString():String
	{
		return "[Register name=\"" + name + "\", longName=\"" + longName + "\", emitCode=" + emitCode + ", range=" + range + ", flags=" + flags + "]";
	}
}

class Sampler
{
	public function Sampler(name:String, flag:uint, mask:uint)
	{
		this.name = name;
		this.flag = flag;
		this.mask = mask;
	}
	
	public var name:String;
	public var flag:uint;
	public var mask:uint;
	
	public function toString():String
	{
		return "[Sampler name=\"" + name + "\", flag=\"" + flag + "\", mask=" + mask + "]";
	}
}