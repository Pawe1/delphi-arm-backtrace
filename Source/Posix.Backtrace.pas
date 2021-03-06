{******************************************************************************}
{                                                                              }
{            Copyright (c) 2014 Jan Rames                                      }
{                                                                              }
{******************************************************************************}
{                                                                              }
{            This Source Code Form is subject to the terms of the              }
{                                                                              }
{                       Mozilla Public License, v. 2.0.                        }
{                                                                              }
{            If a copy of the MPL was not distributed with this file,          }
{            You can obtain one at http://mozilla.org/MPL/2.0/.                }
{                                                                              }
{******************************************************************************}

unit Posix.Backtrace;

interface

{$IF Defined(ANDROID) OR Defined(IOS)}
	{$DEFINE OWN_BACKTRACE}
{$ELSEIF Defined(MACOS)}
	{$DEFINE LIBC_BACKTRACE}
	{$IFDEF CPUX86}
		{$DEFINE EXC_BACKTRACE}
	{$ENDIF}
{$ELSE}
	{$MESSAGE FATAL 'Unsupported OS'}
{$IFEND}

function StackWalk(Data : PPointer; Count : Integer) : Integer; inline;
// execinfo.h shadow procedure
function backtrace(buffer : PPointer; size : Integer) : Integer;
	{$IFDEF LIBC_BACKTRACE}cdecl;{$ENDIF}
{$IFDEF EXC_BACKTRACE}
//Exception stack frame gets corrupted while handling exceptions and own
//backtrace have to be used
function backtrace2(base : NativeUInt; buffer : PPointer; size : Integer) : Integer;
{$ENDIF}

{$IFDEF LIBC_BACKTRACE}
function backtrace_symbols(buffer : PPointer; size : Integer) : PPointer{PPAnsiChar}; cdecl;
procedure backtrace_symbols_free(ptr : Pointer); cdecl;
{$ENDIF}

implementation

{$IFDEF LIBC_BACKTRACE}
uses Posix.Base;
{$ENDIF}

{$IFDEF OWN_BACKTRACE}
const BacktraceLibName = 'backtrace.o';
function get_frame : NativeUInt; cdecl; external BacktraceLibName;
{$WARN SYMBOL_PLATFORM OFF}
{$LINK LibName}
{$WARN SYMBOL_PLATFORM ON}
{$ENDIF OWN_BACKTRACE}

function StackWalk(Data : PPointer; Count : Integer) : Integer; inline;
begin
	Result:=backtrace(Data, Count);
end;

{$IFDEF OWN_BACKTRACE}
function backtrace(buffer : PPointer; size : Integer) : Integer;
const
	MEM_MASK = $FFF00000;
	STACK_MAX_SIZE = 2 * 1024 * 1024; //Default UNIX stack size
var FPp	: Pointer;
	FP	: NativeUInt absolute FPp;
	LR	: Pointer;
	SPMax : NativeUInt;
	SPMin : NativeUInt;
begin
	//Push instruction decrements SP, we're walking stack up
	FP:=get_frame;
	SPMin:=FP;
	SPMax:=SPMin + STACK_MAX_SIZE;
	Result:=0;
	//FP = nil should indicate parent most Stack Frame
	while (size > 0) and (FP <= SPMax) and (FP >= SPMin) and (FP <> 0{nil}) do begin
		//This is how Delphi compiler uses stack, but depends on ABI
		//Delphi probably uses R7 as Frame pointer since it is the least register
		//accessible by THUMB (16-bit) instructions in comparison to ARM (32-bit)
		//instructions see backtrace.c
		LR:=PPointer(FP + 4)^;
		FP:=PNativeUInt(FP)^;

		NativeUInt(buffer^):=NativeUInt(LR) - 3; //LR is set to PC + 3 (branch instruction size is 2 and is adjusted for prefetch)
		Inc(Result);

		Inc(buffer);
		Dec(size);
	end;
	if (size > 0) then buffer^:=nil;
end;
{$ENDIF OWN_BACKTRACE}

{$IFDEF LIBC_BACKTRACE}
function backtrace; external libc name '_backtrace';
function backtrace_symbols; external libc name '_backtrace_symbols';
procedure backtrace_symbols_free; external libc name '_free';
{$ENDIF}

{$IFDEF EXC_BACKTRACE}
function backtrace2(base : NativeUInt; buffer : PPointer; size : Integer) : Integer;
const STACK_MAX_SIZE = 2 * 1024 * 1024;
var SPMin	: NativeUInt;
begin
	SPMin:=base;
	Result:=0;
	while (size > 0) and (base >= SPMin) and (base <> 0) do begin
		buffer^:=PPointer(base + 4)^;
		base:=PNativeInt(base)^;
		Inc(Result);

		Inc(buffer);
		Dec(size);
	end;
	if (size > 0) then buffer^:=nil;
end;
{$ENDIF}


end.
