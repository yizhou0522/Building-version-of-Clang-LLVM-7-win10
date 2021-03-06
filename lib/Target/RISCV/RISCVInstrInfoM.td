//===-- RISCVInstrInfoM.td - RISC-V 'M' instructions -------*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the standard 'M', Integer
// Multiplication and Division instruction set extension.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasStdExtM] in {
def MUL     : ALU_rr<0b0000001, 0b000, "mul">;
def MULH    : ALU_rr<0b0000001, 0b001, "mulh">;
def MULHSU  : ALU_rr<0b0000001, 0b010, "mulhsu">;
def MULHU   : ALU_rr<0b0000001, 0b011, "mulhu">;
def DIV     : ALU_rr<0b0000001, 0b100, "div">;
def DIVU    : ALU_rr<0b0000001, 0b101, "divu">;
def REM     : ALU_rr<0b0000001, 0b110, "rem">;
def REMU    : ALU_rr<0b0000001, 0b111, "remu">;
} // Predicates = [HasStdExtM]

let Predicates = [HasStdExtM, IsRV64] in {
def MULW    : ALUW_rr<0b0000001, 0b000, "mulw">;
def DIVW    : ALUW_rr<0b0000001, 0b100, "divw">;
def DIVUW   : ALUW_rr<0b0000001, 0b101, "divuw">;
def REMW    : ALUW_rr<0b0000001, 0b110, "remw">;
def REMUW   : ALUW_rr<0b0000001, 0b111, "remuw">;
} // Predicates = [HasStdExtM, IsRV64]

//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//

let Predicates = [HasStdExtM] in {
def : PatGprGpr<mul, MUL>;
def : PatGprGpr<mulhs, MULH>;
def : PatGprGpr<mulhu, MULHU>;
// No ISDOpcode for mulhsu
def : PatGprGpr<sdiv, DIV>;
def : PatGprGpr<udiv, DIVU>;
def : PatGprGpr<srem, REM>;
def : PatGprGpr<urem, REMU>;
} // Predicates = [HasStdExtM]
