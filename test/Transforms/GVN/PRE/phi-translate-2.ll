; RUN: opt < %s -debugify -gvn -S | FileCheck %s
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

@a = common global [100 x i64] zeroinitializer, align 16
@b = common global [100 x i64] zeroinitializer, align 16
@g1 = common global i64 0, align 8
@g2 = common global i64 0, align 8
@g3 = common global i64 0, align 8
declare i64 @goo(...) local_unnamed_addr #1

define void @test1(i64 %a, i64 %b, i64 %c, i64 %d) {
entry:
  %mul = mul nsw i64 %b, %a
  store i64 %mul, i64* @g1, align 8
  %t0 = load i64, i64* @g2, align 8
  %cmp = icmp sgt i64 %t0, 3
  br i1 %cmp, label %if.then, label %if.end

if.then:                                          ; preds = %entry
  %mul2 = mul nsw i64 %d, %c
  store i64 %mul2, i64* @g2, align 8
  br label %if.end

; Check phi-translate works and mul is removed.
; CHECK-LABEL: @test1(
; CHECK: if.end:
; CHECK: %[[MULPHI:.*]] = phi i64 [ {{.*}}, %if.then ], [ %mul, %entry ]
; CHECK-NOT: = mul
; CHECK: store i64 %[[MULPHI]], i64* @g3, align 8
if.end:                                           ; preds = %if.then, %entry
  %b.addr.0 = phi i64 [ %d, %if.then ], [ %b, %entry ]
  %a.addr.0 = phi i64 [ %c, %if.then ], [ %a, %entry ]
  %mul3 = mul nsw i64 %a.addr.0, %b.addr.0
  store i64 %mul3, i64* @g3, align 8
  ret void
}

define void @test2(i64 %i) {
entry:
  %arrayidx = getelementptr inbounds [100 x i64], [100 x i64]* @a, i64 0, i64 %i
  %t0 = load i64, i64* %arrayidx, align 8
  %arrayidx1 = getelementptr inbounds [100 x i64], [100 x i64]* @b, i64 0, i64 %i
  %t1 = load i64, i64* %arrayidx1, align 8
  %mul = mul nsw i64 %t1, %t0
  store i64 %mul, i64* @g1, align 8
  %cmp = icmp sgt i64 %mul, 3
  br i1 %cmp, label %if.then, label %if.end

; Check phi-translate works for the phi generated by loadpre. A new mul will be
; inserted in if.then block.
; CHECK-LABEL: @test2(
; CHECK: if.then:
; CHECK: %[[MUL_THEN:.*]] = mul
; CHECK: br label %if.end
if.then:                                          ; preds = %entry
  %call = tail call i64 (...) @goo() #2
  store i64 %call, i64* @g2, align 8
  br label %if.end

; CHECK: if.end:
; CHECK: %[[MULPHI:.*]] = phi i64 [ %[[MUL_THEN]], %if.then ], [ %mul, %entry ]
; CHECK-NOT: = mul
; CHECK: store i64 %[[MULPHI]], i64* @g3, align 8
if.end:                                           ; preds = %if.then, %entry
  %i.addr.0 = phi i64 [ 3, %if.then ], [ %i, %entry ]
  %arrayidx3 = getelementptr inbounds [100 x i64], [100 x i64]* @a, i64 0, i64 %i.addr.0
  %t2 = load i64, i64* %arrayidx3, align 8
  %arrayidx4 = getelementptr inbounds [100 x i64], [100 x i64]* @b, i64 0, i64 %i.addr.0
  %t3 = load i64, i64* %arrayidx4, align 8
  %mul5 = mul nsw i64 %t3, %t2
  store i64 %mul5, i64* @g3, align 8
  ret void
}

; Check phi-translate doesn't go through backedge, which may lead to incorrect
; pre transformation.
; CHECK: for.end:
; CHECK-NOT: %{{.*pre-phi}} = phi
; CHECK: ret void
define void @test3(i64 %N, i64* nocapture readonly %a) {
entry:
  br label %for.cond

for.cond:                                         ; preds = %for.body, %entry
  %i.0 = phi i64 [ 0, %entry ], [ %add, %for.body ]
  %add = add nuw nsw i64 %i.0, 1
  %arrayidx = getelementptr inbounds i64, i64* %a, i64 %add
  %tmp0 = load i64, i64* %arrayidx, align 8
  %cmp = icmp slt i64 %i.0, %N
  br i1 %cmp, label %for.body, label %for.end

for.body:                                         ; preds = %for.cond
  %call = tail call i64 (...) @goo() #2
  %add1 = sub nsw i64 0, %call
  %tobool = icmp eq i64 %tmp0, %add1
  br i1 %tobool, label %for.cond, label %for.end

for.end:                                          ; preds = %for.body, %for.cond
  %i.0.lcssa = phi i64 [ %i.0, %for.body ], [ %i.0, %for.cond ]
  %arrayidx2 = getelementptr inbounds i64, i64* %a, i64 %i.0.lcssa
  %tmp1 = load i64, i64* %arrayidx2, align 8
  store i64 %tmp1, i64* @g1, align 8
  ret void
}

; It is incorrect to use the value of %andres in last loop iteration
; to do pre.
; CHECK-LABEL: @test4(
; CHECK: for.body:
; CHECK-NOT: %andres.pre-phi = phi i32
; CHECK: br i1 %tobool1

define i32 @test4(i32 %cond, i32 %SectionAttrs.0231.ph, i32 *%AttrFlag) {
for.body.preheader:
  %t514 = load volatile i32, i32* %AttrFlag
  br label %for.body

for.body:
  %t320 = phi i32 [ %t334, %bb343 ], [ %t514, %for.body.preheader ]
  %andres = and i32 %t320, %SectionAttrs.0231.ph
  %tobool1 = icmp eq i32 %andres, 0
  br i1 %tobool1, label %bb343, label %critedge.loopexit

bb343:
  %t334 = load volatile i32, i32* %AttrFlag
  %tobool2 = icmp eq i32 %cond, 0
  br i1 %tobool2, label %critedge.loopexit, label %for.body

critedge.loopexit:
  unreachable
}

; Check sub expression will be pre transformed.
; CHECK-LABEL: @test5(
; CHECK: entry:
; CHECK: %sub.ptr.sub = sub i64 %sub.ptr.lhs.cast, %sub.ptr.rhs.cast
; CHECK: br i1 %cmp
; CHECK: if.then2:
; CHECK: %[[PTRTOINT:.*]] = ptrtoint i32* %add.ptr to i64
; CHECK: %[[SUB:.*]] = sub i64 %sub.ptr.lhs.cast, %[[PTRTOINT]]
; CHECK: br label %if.end3
; CHECK: if.end3:
; CHECK: %[[PREPHI:.*]] = phi i64 [ %sub.ptr.sub, %if.else ], [ %[[SUB]], %if.then2 ], [ %sub.ptr.sub, %entry ]
; CHECK: call void @llvm.dbg.value(metadata i32* %p.0, metadata [[var_p0:![0-9]+]], metadata !DIExpression())
; CHECK: call void @llvm.dbg.value(metadata i64 %sub.ptr.rhs.cast5.pre-phi, metadata [[var_sub_ptr:![0-9]+]], metadata !DIExpression())
; CHECK: %[[DIV:.*]] = ashr exact i64 %[[PREPHI]], 2
; CHECK: ret i64 %[[DIV]]

declare void @bar(...) local_unnamed_addr #1

; Function Attrs: nounwind uwtable
define i64 @test5(i32* %start, i32* %e, i32 %n1, i32 %n2) local_unnamed_addr #0 {
entry:
  %sub.ptr.lhs.cast = ptrtoint i32* %e to i64
  %sub.ptr.rhs.cast = ptrtoint i32* %start to i64
  %sub.ptr.sub = sub i64 %sub.ptr.lhs.cast, %sub.ptr.rhs.cast
  %cmp = icmp sgt i64 %sub.ptr.sub, 4000
  br i1 %cmp, label %if.then, label %if.end3

if.then:                                          ; preds = %entry
  %cmp1 = icmp sgt i32 %n1, %n2
  br i1 %cmp1, label %if.then2, label %if.else

if.then2:                                         ; preds = %if.then
  %add.ptr = getelementptr inbounds i32, i32* %start, i64 800
  br label %if.end3

if.else:                                          ; preds = %if.then
  tail call void (...) @bar() #2
  br label %if.end3

if.end3:                                          ; preds = %if.then2, %if.else, %entry
  %p.0 = phi i32* [ %add.ptr, %if.then2 ], [ %start, %if.else ], [ %start, %entry ]
  %sub.ptr.rhs.cast5 = ptrtoint i32* %p.0 to i64
  %sub.ptr.sub6 = sub i64 %sub.ptr.lhs.cast, %sub.ptr.rhs.cast5
  %sub.ptr.div7 = ashr exact i64 %sub.ptr.sub6, 2
  ret i64 %sub.ptr.div7
}

; Here the load from arrayidx1 is partially redundant, but its value is
; available in if.then. Check that we correctly phi-translate to the phi that
; the load has been replaced with.
; CHECK-LABEL: @test6
define void @test6(i32* %ptr) {
; CHECK: entry:
; CHECK: %[[PREGEP:.*]] = getelementptr inbounds i32, i32* %ptr, i64 1
; CHECK: %[[PRE:.*]] = load i32, i32* %[[PREGEP]]
entry:
  br label %while

; CHECK: while:
; CHECK: %[[PHI1:.*]] = phi i32 [ %[[PRE]], %entry ], [ %[[PHI2:.*]], %if.end ]
; CHECK-NOT: load i32, i32* %arrayidx1
; CHECK: %[[LOAD:.*]] = load i32, i32* %arrayidx2
while:
  %i = phi i64 [ 1, %entry ], [ %i.next, %if.end ]
  %arrayidx1 = getelementptr inbounds i32, i32* %ptr, i64 %i
  %0 = load i32, i32* %arrayidx1, align 4
  %i.next = add nuw nsw i64 %i, 1
  %arrayidx2 = getelementptr inbounds i32, i32* %ptr, i64 %i.next
  %1 = load i32, i32* %arrayidx2, align 4
  %cmp = icmp sgt i32 %0, %1
  br i1 %cmp, label %if.then, label %if.end

if.then:
  store i32 %1, i32* %arrayidx1, align 4
  store i32 %0, i32* %arrayidx2, align 4
  br label %if.end

; CHECK: if.then:
; CHECK: %[[PHI2]] = phi i32 [ %[[PHI1]], %if.then ], [ %[[LOAD]], %while ]
if.end:
  br i1 undef, label %while.end, label %while

while.end:
  ret void
}

; CHECK: [[var_p0]] = !DILocalVariable
; CHECK: [[var_sub_ptr]] = !DILocalVariable
