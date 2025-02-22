; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -simplifycfg -dce -instcombine -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,simplifycfg,dce,instcombine"  -enzyme-preopt=false -S | FileCheck %s

; Function Attrs: nounwind uwtable
define dso_local void @memcpy_float(double* nocapture %dst, double* nocapture readonly %src, i64 %num) #0 {
entry:
  %0 = bitcast double* %dst to i8*
  %1 = bitcast double* %src to i8*
  tail call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 1 %0, i8* align 1 %1, i64 %num, i1 false)
  ret void
}

; Function Attrs: argmemonly nounwind
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture writeonly, i8* nocapture readonly, i64, i1) #1

; Function Attrs: nounwind uwtable
define dso_local void @dmemcpy_float(double* %dst, double* %dstp, double* %src, double* %srcp, i64 %n) local_unnamed_addr #0 {
entry:
  tail call void (...) @__enzyme_autodiff.f64(void (double*, double*, i64)* nonnull @memcpy_float, double* %dst, double* %dstp, double* %src, double* %srcp, i64 %n) #3
  ret void
}

declare void @__enzyme_autodiff.f64(...) local_unnamed_addr

; Function Attrs: noinline nounwind uwtable
define dso_local void @submemcpy_float(double* nocapture %smdst, double* nocapture readonly %smsrc, i64 %num) local_unnamed_addr #2 {
entry:
  %0 = bitcast double* %smdst to i8*
  %1 = bitcast double* %smsrc to i8*
  tail call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 1 %0, i8* align 1 %1, i64 %num, i1 false)
  ret void
}

; Function Attrs: nounwind uwtable
define dso_local void @memcpyaugment_float(double* nocapture %dst, double* nocapture readonly %src, i64 %num) #0 {
entry:
  tail call void @submemcpy_float(double* %dst, double* %src, i64 %num)
  store double 0.000000e+00, double* %dst
  ret void
}

; Function Attrs: nounwind uwtable
define dso_local void @dmemcpyaugment_ptr(double* %dst, double* %dstp, double* %src, double* %srcp, i64 %n) local_unnamed_addr #0 {
entry:
  tail call void (...) @__enzyme_autodiff.f64(void (double*, double*, i64)* nonnull @memcpyaugment_float, double* %dst, double* %dstp, double* %src, double* %srcp, i64 %n) #3
  ret void
}

attributes #0 = { nounwind uwtable }
attributes #1 = { argmemonly nounwind }
attributes #2 = { noinline nounwind uwtable }
attributes #3 = { nounwind }

; CHECK: define internal {{(dso_local )?}}void @diffememcpy_float(double* nocapture %dst, double* nocapture %"dst'", double* nocapture readonly %src, double* nocapture %"src'", i64 %num) 
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = bitcast double* %dst to i8*
; CHECK-NEXT:   %1 = bitcast double* %src to i8*
; CHECK-NEXT:   tail call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 1 %0, i8* align 1 %1, i64 %num, i1 false)
; CHECK-NEXT:   %2 = lshr i64 %num, 3
; CHECK-NEXT:   %3 = {{(icmp eq i64 %2, 0|icmp ult i64 %num, 8)}}
; CHECK-NEXT:   br i1 %3, label %__enzyme_memcpyadd_doubleda1sa1.exit, label %for.body.i

; CHECK: for.body.i:                                       ; preds = %for.body.i, %entry
; CHECK-NEXT:   %idx.i = phi i64 [ 0, %entry ], [ %idx.next.i, %for.body.i ]
; CHECK-NEXT:   %dst.i.i = getelementptr inbounds double, double* %"dst'", i64 %idx.i
; CHECK-NEXT:   %dst.i.l.i = load double, double* %dst.i.i
; CHECK-NEXT:   store double 0.000000e+00, double* %dst.i.i
; CHECK-NEXT:   %src.i.i = getelementptr inbounds double, double* %"src'", i64 %idx.i
; CHECK-NEXT:   %src.i.l.i = load double, double* %src.i.i
; CHECK-NEXT:   %4 = fadd fast double %src.i.l.i, %dst.i.l.i
; CHECK-NEXT:   store double %4, double* %src.i.i
; CHECK-NEXT:   %idx.next.i = add nuw i64 %idx.i, 1
; CHECK-NEXT:   %5 = icmp eq i64 %2, %idx.next.i
; CHECK-NEXT:   br i1 %5, label %__enzyme_memcpyadd_doubleda1sa1.exit, label %for.body.i

; CHECK: __enzyme_memcpyadd_doubleda1sa1.exit:             ; preds = %entry, %for.body.i
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal {{(dso_local )?}}void @__enzyme_memcpyadd_doubleda1sa1(double* nocapture %dst, double* nocapture %src, i64 %num) #[[mymemattrs:.+]] {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = icmp eq i64 %num, 0
; CHECK-NEXT:   br i1 %0, label %for.end, label %for.body

; CHECK: for.body:                                        
; CHECK-NEXT:   %idx = phi i64 [ 0, %entry ], [ %idx.next, %for.body ] 
; CHECK-NEXT:   %dst.i = getelementptr inbounds double, double* %dst, i64 %idx
; CHECK-NEXT:   %dst.i.l = load double, double* %dst.i
; CHECK-NEXT:   store double 0.000000e+00, double* %dst.i
; CHECK-NEXT:   %src.i = getelementptr inbounds double, double* %src, i64 %idx
; CHECK-NEXT:   %src.i.l = load double, double* %src.i
; CHECK-NEXT:   %1 = fadd fast double %src.i.l, %dst.i.l
; CHECK-NEXT:   store double %1, double* %src.i
; CHECK-NEXT:   %idx.next = add nuw i64 %idx, 1
; CHECK-NEXT:   %2 = icmp eq i64 %idx.next, %num
; CHECK-NEXT:   br i1 %2, label %for.end, label %for.body

; CHECK: for.end:                                         
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal {{(dso_local )?}}void @diffememcpyaugment_float(double* nocapture %dst, double* nocapture %"dst'", double* nocapture readonly %src, double* nocapture %"src'", i64 %num) 
; CHECK-NEXT: entry:
; CHECK-NEXT:   call void @augmented_submemcpy_float(double* %dst, double* %"dst'", double* %src, double* %"src'", i64 %num)
; CHECK-NEXT:   store double 0.000000e+00, double* %dst
; CHECK-NEXT:   store double 0.000000e+00, double* %"dst'"
; CHECK-NEXT:   call void @diffesubmemcpy_float(double* {{(nonnull )?}}%dst, double* {{(nonnull )?}}%"dst'", double* %src, double* %"src'", i64 %num)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal {{(dso_local )?}}void @augmented_submemcpy_float(double* nocapture %smdst, double* nocapture %"smdst'", double* nocapture readonly %smsrc, double* nocapture %"smsrc'", i64 %num) 
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = bitcast double* %smdst to i8*
; CHECK-NEXT:   %1 = bitcast double* %smsrc to i8*
; CHECK-NEXT:   tail call void @llvm.memcpy.p0i8.p0i8.i64(i8* {{(align 1  )?}}%0, i8* {{(align 1  )?}}%1, i64 %num, i1 false)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal {{(dso_local )?}}void @diffesubmemcpy_float(double* nocapture %smdst, double* nocapture %"smdst'", double* nocapture readonly %smsrc, double* nocapture %"smsrc'", i64 %num)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = lshr i64 %num, 3
; CHECK-NEXT:   %1 = {{(icmp eq i64 %0, 0|icmp ult i64 %num, 8)}}
; CHECK-NEXT:   br i1 %1, label %__enzyme_memcpyadd_doubleda1sa1.exit, label %for.body.i

; CHECK: for.body.i:                                       ; preds = %for.body.i, %entry
; CHECK-NEXT:   %idx.i = phi i64 [ 0, %entry ], [ %idx.next.i, %for.body.i ]
; CHECK-NEXT:   %dst.i.i = getelementptr inbounds double, double* %"smdst'", i64 %idx.i
; CHECK-NEXT:   %dst.i.l.i = load double, double* %dst.i.i
; CHECK-NEXT:   store double 0.000000e+00, double* %dst.i.i
; CHECK-NEXT:   %src.i.i = getelementptr inbounds double, double* %"smsrc'", i64 %idx.i
; CHECK-NEXT:   %src.i.l.i = load double, double* %src.i.i
; CHECK-NEXT:   %2 = fadd fast double %src.i.l.i, %dst.i.l.i
; CHECK-NEXT:   store double %2, double* %src.i.i
; CHECK-NEXT:   %idx.next.i = add nuw i64 %idx.i, 1
; CHECK-NEXT:   %3 = icmp eq i64 %0, %idx.next.i
; CHECK-NEXT:   br i1 %3, label %__enzyme_memcpyadd_doubleda1sa1.exit, label %for.body.i

; CHECK: __enzyme_memcpyadd_doubleda1sa1.exit:             ; preds = %entry, %for.body.i
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: attributes #[[mymemattrs]] = { alwaysinline argmemonly nounwind }
