; RUN: opt < %s -analyze -iv-users -S | FileCheck %s

; This is a regression test for the commit rL327362.

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128-ni:1"
target triple = "x86_64-unknown-linux-gnu"

define void @test(i64 %a, i64* %p) {
entry:
  br label %first_loop

first_loop:
  %i = phi i64 [20, %entry], [%i.next, %first_loop]
  %i.next = add nuw nsw i64 %i, 1
  %cond1 = icmp ult i64 %i.next, %a
  br i1 %cond1, label %first_loop, label %middle_block

middle_block:
  %b = load i64, i64* %p
  %cmp = icmp ult i64 %i, %b
; When SCEV will try to compute the initial value for %j
; it will observe umax generated by this select.
; When it will try to simplify this umax it will invoke
; isKnownPredicate with AddRec for %i and unknown SCEV for %b.
; As a result we find MDL == first_loop where %b is not available
; at loop entry.
; CHECK: IV Users for loop %second_loop with backedge-taken count{{.*}}umax
  %s = select i1 %cmp, i64 %i, i64 %b
  br label %second_loop

second_loop:
  %j = phi i64 [%s, %middle_block], [%j.next, %second_loop]
  %j.next = add nuw nsw i64 %j, 1
  %cond2 = icmp ult i64 %j.next, 100
  br i1 %cond2, label %second_loop, label %return

return:
  ret void
}
