; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,inline,mem2reg,gvn,early-cse-memssa,instcombine,instsimplify,simplifycfg,adce,licm,correlated-propagation,instcombine,correlated-propagation,adce,instsimplify,correlated-propagation,jump-threading,instsimplify,early-cse,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

; #include <stdlib.h>
; #include <stdio.h>
;
; struct n {
;     double *values;
;     struct n *next;
; };
;
; __attribute__((noinline))
; double sum_list(const struct n *__restrict node, unsigned long times) {
;     double sum = 0;
;     for(const struct n *val = node; val != 0; val = val->next) {
;         for(int i=0; i<=times; i++) {
;             sum += val->values[i];
;         }
;     }
;     return sum;
; }
;
; double list_creator(double x, unsigned long n, unsigned long times) {
;     struct n *list = 0;
;     for(int i=0; i<=n; i++) {
;         struct n *newnode = malloc(sizeof(struct n));
;         newnode->next = list;
;         newnode->values = malloc(sizeof(double)*(times+1));
;         for(int j=0; j<=times; j++) {
;             newnode->values[j] = x;
;         }
;         list = newnode;
;     }
;     return sum_list(list, times);
; }
;
; __attribute__((noinline))
; double derivative(double x, unsigned long n, unsigned long times) {
;     return __builtin_autodiff(list_creator, x, n, times);
; }
;
; int main(int argc, char** argv) {
;     double x = atof(argv[1]);
;     unsigned long n = atoi(argv[2]);
;     unsigned long times = atoi(argv[3]);
;     printf("x=%f\n", x);
;     double xp = derivative(x, n, times);
;     printf("xp=%f\n", xp);
;     return 0;
; }

%struct.n = type { double*, %struct.n* }

@.str = private unnamed_addr constant [6 x i8] c"x=%f\0A\00", align 1
@.str.1 = private unnamed_addr constant [7 x i8] c"xp=%f\0A\00", align 1

; Function Attrs: noinline norecurse nounwind readonly uwtable
define dso_local double @sum_list(%struct.n* noalias readonly %node, i64 %times) local_unnamed_addr #0 {
entry:
  %cmp18 = icmp eq %struct.n* %node, null
  br i1 %cmp18, label %for.cond.cleanup, label %for.cond1.preheader

for.cond1.preheader:                              ; preds = %for.cond.cleanup4, %entry
  %val.020 = phi %struct.n* [ %1, %for.cond.cleanup4 ], [ %node, %entry ]
  %sum.019 = phi double [ %add, %for.cond.cleanup4 ], [ 0.000000e+00, %entry ]
  %values = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 0
  %0 = load double*, double** %values, align 8, !tbaa !2
  br label %for.body5

for.cond.cleanup:                                 ; preds = %for.cond.cleanup4, %entry
  %sum.0.lcssa = phi double [ 0.000000e+00, %entry ], [ %add, %for.cond.cleanup4 ]
  ret double %sum.0.lcssa

for.cond.cleanup4:                                ; preds = %for.body5
  %next = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 1
  %1 = load %struct.n*, %struct.n** %next, align 8, !tbaa !7
  %cmp = icmp eq %struct.n* %1, null
  br i1 %cmp, label %for.cond.cleanup, label %for.cond1.preheader

for.body5:                                        ; preds = %for.body5, %for.cond1.preheader
  %indvars.iv = phi i64 [ 0, %for.cond1.preheader ], [ %indvars.iv.next, %for.body5 ]
  %sum.116 = phi double [ %sum.019, %for.cond1.preheader ], [ %add, %for.body5 ]
  %arrayidx = getelementptr inbounds double, double* %0, i64 %indvars.iv
  %2 = load double, double* %arrayidx, align 8, !tbaa !8
  %add = fadd fast double %2, %sum.116
  %indvars.iv.next = add nuw i64 %indvars.iv, 1
  %exitcond = icmp eq i64 %indvars.iv, %times
  br i1 %exitcond, label %for.cond.cleanup4, label %for.body5
}

; Function Attrs: nounwind uwtable
define dso_local double @list_creator(double %x, i64 %n, i64 %times) #1 {
entry:
  %add = shl i64 %times, 3
  %mul = add i64 %add, 8
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.cond.cleanup7
  %call13 = tail call fast double @sum_list(%struct.n* %2, i64 %times)
  ret double %call13

for.body:                                         ; preds = %for.cond.cleanup7, %entry
  %indvars.iv30 = phi i64 [ 0, %entry ], [ %indvars.iv.next31, %for.cond.cleanup7 ]
  %list.029 = phi %struct.n* [ null, %entry ], [ %2, %for.cond.cleanup7 ]
  %call = tail call noalias i8* @malloc(i64 16) #4
  %next = getelementptr inbounds i8, i8* %call, i64 8
  %0 = bitcast i8* %next to %struct.n**
  store %struct.n* %list.029, %struct.n** %0, align 8, !tbaa !7
  %call2 = tail call noalias i8* @malloc(i64 %mul) #4
  %1 = bitcast i8* %call to i8**
  store i8* %call2, i8** %1, align 8, !tbaa !2
  %.cast = bitcast i8* %call2 to double*
  br label %for.body8

for.cond.cleanup7:                                ; preds = %for.body8
  %2 = bitcast i8* %call to %struct.n*
  %indvars.iv.next31 = add nuw i64 %indvars.iv30, 1
  %exitcond32 = icmp eq i64 %indvars.iv30, %n
  br i1 %exitcond32, label %for.cond.cleanup, label %for.body

for.body8:                                        ; preds = %for.body8, %for.body
  %indvars.iv = phi i64 [ 0, %for.body ], [ %indvars.iv.next, %for.body8 ]
  %arrayidx = getelementptr inbounds double, double* %.cast, i64 %indvars.iv
  store double %x, double* %arrayidx, align 8, !tbaa !8
  %indvars.iv.next = add nuw i64 %indvars.iv, 1
  %exitcond = icmp eq i64 %indvars.iv, %times
  br i1 %exitcond, label %for.cond.cleanup7, label %for.body8
}

; Function Attrs: nounwind
declare dso_local noalias i8* @malloc(i64) local_unnamed_addr #2

; Function Attrs: noinline nounwind uwtable
define dso_local double @derivative(double %x, i64 %n, i64 %times) local_unnamed_addr #3 {
entry:
  %0 = tail call double (double (double, i64, i64)*, ...) @__enzyme_autodiff(double (double, i64, i64)* nonnull @list_creator, double %x, i64 %n, i64 %times)
  ret double %0
}

; Function Attrs: nounwind
declare double @__enzyme_autodiff(double (double, i64, i64)*, ...) #4

; Function Attrs: nounwind uwtable
define dso_local i32 @main(i32 %argc, i8** nocapture readonly %argv) local_unnamed_addr #1 {
entry:
  %arrayidx = getelementptr inbounds i8*, i8** %argv, i64 1
  %0 = load i8*, i8** %arrayidx, align 8, !tbaa !10
  %call.i = tail call fast double @strtod(i8* nocapture nonnull %0, i8** null) #4
  %arrayidx1 = getelementptr inbounds i8*, i8** %argv, i64 2
  %1 = load i8*, i8** %arrayidx1, align 8, !tbaa !10
  %call.i16 = tail call i64 @strtol(i8* nocapture nonnull %1, i8** null, i32 10) #4
  %sext = shl i64 %call.i16, 32
  %conv = ashr exact i64 %sext, 32
  %arrayidx3 = getelementptr inbounds i8*, i8** %argv, i64 3
  %2 = load i8*, i8** %arrayidx3, align 8, !tbaa !10
  %call.i17 = tail call i64 @strtol(i8* nocapture nonnull %2, i8** null, i32 10) #4
  %sext19 = shl i64 %call.i17, 32
  %conv5 = ashr exact i64 %sext19, 32
  %call6 = tail call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str, i64 0, i64 0), double %call.i)
  %call7 = tail call fast double @derivative(double %call.i, i64 %conv, i64 %conv5)
  %call8 = tail call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.1, i64 0, i64 0), double %call7)
  ret i32 0
}

; Function Attrs: nounwind
declare dso_local i32 @printf(i8* nocapture readonly, ...) local_unnamed_addr #2

; Function Attrs: nounwind
declare dso_local double @strtod(i8* readonly, i8** nocapture) local_unnamed_addr #2

; Function Attrs: nounwind
declare dso_local i64 @strtol(i8* readonly, i8** nocapture, i32) local_unnamed_addr #2

attributes #0 = { noinline norecurse nounwind readonly uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #1 = { nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #2 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #3 = { noinline nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #4 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.1.0 "}
!2 = !{!3, !4, i64 0}
!3 = !{!"n", !4, i64 0, !4, i64 8}
!4 = !{!"any pointer", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!3, !4, i64 8}
!8 = !{!9, !9, i64 0}
!9 = !{!"double", !5, i64 0}
!10 = !{!4, !4, i64 0}


; CHECK: define dso_local double @derivative(double %x, i64 %n, i64 %times)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %add.i = shl i64 %times, 3
; CHECK-NEXT:   %mul.i = add i64 %add.i, 8
; CHECK-NEXT:   %0 = shl i64 %n, 3
; CHECK-NEXT:   %mallocsize.i = add i64 %0, 8
; CHECK-NEXT:   %malloccall.i = call noalias nonnull i8* @malloc(i64 %mallocsize.i) #4
; CHECK-NEXT:   %"call2'mi_malloccache.i" = bitcast i8* %malloccall.i to i8**
; CHECK-NEXT:   %malloccall7.i = call noalias nonnull i8* @malloc(i64 %mallocsize.i) #4
; CHECK-NEXT:   %call2_malloccache.i = bitcast i8* %malloccall7.i to i8**
; CHECK-NEXT:   %malloccall14.i = call noalias nonnull i8* @malloc(i64 %mallocsize.i) #4
; CHECK-NEXT:   %"call'mi_malloccache.i" = bitcast i8* %malloccall14.i to i8**
; CHECK-NEXT:   %malloccall20.i = call noalias nonnull i8* @malloc(i64 %mallocsize.i) #4
; CHECK-NEXT:   %call_malloccache.i = bitcast i8* %malloccall20.i to i8**
; CHECK-NEXT:   br label %for.body.i

; CHECK: for.cond.cleanup.i:                               ; preds = %for.cond.cleanup7.i
; CHECK-NEXT:   call void @diffesum_list(%struct.n* nonnull %8, %struct.n* nonnull %"'ipc.i", i64 %times, double 1.000000e+00) #4
; CHECK-NEXT:   br label %invertfor.cond.cleanup7.i

; CHECK: for.body.i:                                       ; preds = %for.cond.cleanup7.i, %entry
; CHECK-NEXT:   %iv.i = phi i64 [ %iv.next.i, %for.cond.cleanup7.i ], [ 0, %entry ]
; CHECK-NEXT:   %1 = phi %struct.n* [ %"'ipc.i", %for.cond.cleanup7.i ], [ null, %entry ]
; CHECK-NEXT:   %list.029.i = phi %struct.n* [ %8, %for.cond.cleanup7.i ], [ null, %entry ]
; CHECK-NEXT:   %iv.next.i = add nuw nsw i64 %iv.i, 1
; CHECK-NEXT:   %call.i = call noalias nonnull dereferenceable(16) dereferenceable_or_null(16) i8* @malloc(i64 16) #10
; CHECK-NEXT:   %"call'mi.i" = call noalias nonnull dereferenceable(16) dereferenceable_or_null(16) i8* @malloc(i64 16) #10
; CHECK-NEXT:   call void @llvm.memset.p0i8.i64(i8* nonnull align 1 dereferenceable(16) dereferenceable_or_null(16) %"call'mi.i", i8 0, i64 16, i1 false) #4
; CHECK-NEXT:   %"next'ipg.i" = getelementptr inbounds i8, i8* %"call'mi.i", i64 8
; CHECK-NEXT:   %next.i = getelementptr inbounds i8, i8* %call.i, i64 8
; CHECK-NEXT:   %"'ipc9.i" = bitcast i8* %"next'ipg.i" to %struct.n**
; CHECK-NEXT:   %2 = bitcast i8* %next.i to %struct.n**
; CHECK-NEXT:   store %struct.n* %1, %struct.n** %"'ipc9.i", align 8
; CHECK-NEXT:   %3 = getelementptr inbounds i8*, i8** %call_malloccache.i, i64 %iv.i
; CHECK-NEXT:   store i8* %call.i, i8** %3, align 8, !invariant.group !15
; CHECK-NEXT:   %4 = getelementptr inbounds i8*, i8** %"call'mi_malloccache.i", i64 %iv.i
; CHECK-NEXT:   store i8* %"call'mi.i", i8** %4, align 8, !invariant.group !16
; CHECK-NEXT:   store %struct.n* %list.029.i, %struct.n** %2, align 8, !tbaa !7
; CHECK-NEXT:   %call2.i = call noalias i8* @malloc(i64 %mul.i) #10
; CHECK-NEXT:   %"call2'mi.i" = call noalias nonnull i8* @malloc(i64 %mul.i) #10
; CHECK-NEXT:   call void @llvm.memset.p0i8.i64(i8* nonnull align 1 %"call2'mi.i", i8 0, i64 %mul.i, i1 false) #4
; CHECK-NEXT:   %"'ipc1.i" = bitcast i8* %"call'mi.i" to i8**
; CHECK-NEXT:   %5 = bitcast i8* %call.i to i8**
; CHECK-NEXT:   store i8* %"call2'mi.i", i8** %"'ipc1.i", align 8
; CHECK-NEXT:   %6 = getelementptr inbounds i8*, i8** %call2_malloccache.i, i64 %iv.i
; CHECK-NEXT:   store i8* %call2.i, i8** %6, align 8, !invariant.group !22
; CHECK-NEXT:   %7 = getelementptr inbounds i8*, i8** %"call2'mi_malloccache.i", i64 %iv.i
; CHECK-NEXT:   store i8* %"call2'mi.i", i8** %7, align 8, !invariant.group !23
; CHECK-NEXT:   store i8* %call2.i, i8** %5, align 8, !tbaa !2
; CHECK-NEXT:   %.cast.i = bitcast i8* %call2.i to double*
; CHECK-NEXT:   br label %for.body8.i

; CHECK: for.cond.cleanup7.i:                              ; preds = %for.body8.i
; CHECK-NEXT:   %"'ipc.i" = bitcast i8* %"call'mi.i" to %struct.n*
; CHECK-NEXT:   %8 = bitcast i8* %call.i to %struct.n*
; CHECK-NEXT:   %exitcond32.i = icmp eq i64 %iv.i, %n
; CHECK-NEXT:   br i1 %exitcond32.i, label %for.cond.cleanup.i, label %for.body.i

; CHECK: for.body8.i:                                      ; preds = %for.body8.i, %for.body.i
; CHECK-NEXT:   %iv1.i = phi i64 [ %iv.next2.i, %for.body8.i ], [ 0, %for.body.i ]
; CHECK-NEXT:   %iv.next2.i = add nuw nsw i64 %iv1.i, 1
; CHECK-NEXT:   %arrayidx.i = getelementptr inbounds double, double* %.cast.i, i64 %iv1.i
; CHECK-NEXT:   store double %x, double* %arrayidx.i, align 8, !tbaa !8
; CHECK-NEXT:   %exitcond.i = icmp eq i64 %iv1.i, %times
; CHECK-NEXT:   br i1 %exitcond.i, label %for.cond.cleanup7.i, label %for.body8.i

; CHECK: invertfor.body.i:                                 ; preds = %invertfor.body8.i
; CHECK-NEXT:   call void @free(i8* nonnull %.pre) #4
; CHECK-NEXT:   %9 = getelementptr inbounds i8*, i8** %call2_malloccache.i, i64 %"iv'ac.i.0"
; CHECK-NEXT:   %10 = load i8*, i8** %9, align 8, !invariant.group !22
; CHECK-NEXT:   call void @free(i8* %10) #4
; CHECK-NEXT:   %11 = getelementptr inbounds i8*, i8** %"call'mi_malloccache.i", i64 %"iv'ac.i.0"
; CHECK-NEXT:   %12 = load i8*, i8** %11, align 8, !invariant.group !16
; CHECK-NEXT:   call void @free(i8* nonnull %12) #4
; CHECK-NEXT:   %13 = getelementptr inbounds i8*, i8** %call_malloccache.i, i64 %"iv'ac.i.0"
; CHECK-NEXT:   %14 = load i8*, i8** %13, align 8, !invariant.group !15
; CHECK-NEXT:   call void @free(i8* %14) #4
; CHECK-NEXT:   %15 = icmp eq i64 %"iv'ac.i.0", 0
; CHECK-NEXT:   br i1 %15, label %diffelist_creator.exit, label %incinvertfor.body.i

; CHECK: incinvertfor.body.i:                              ; preds = %invertfor.body.i
; CHECK-NEXT:   %16 = add nsw i64 %"iv'ac.i.0", -1
; CHECK-NEXT:   br label %invertfor.cond.cleanup7.i

; CHECK: invertfor.cond.cleanup7.i:                        ; preds = %incinvertfor.body.i, %for.cond.cleanup.i
; CHECK-NEXT:   %"x'de.i.0" = phi double [ 0.000000e+00, %for.cond.cleanup.i ], [ %18, %incinvertfor.body.i ]
; CHECK-NEXT:   %"iv'ac.i.0" = phi i64 [ %n, %for.cond.cleanup.i ], [ %16, %incinvertfor.body.i ]
; CHECK-NEXT:   %.phi.trans.insert = getelementptr inbounds i8*, i8** %"call2'mi_malloccache.i", i64 %"iv'ac.i.0"
; CHECK-NEXT:   %.pre = load i8*, i8** %.phi.trans.insert, align 8, !invariant.group !23
; CHECK-NEXT:   %".cast'ipc_unwrap.i" = bitcast i8* %.pre to double*
; CHECK-NEXT:   br label %invertfor.body8.i

; CHECK: invertfor.body8.i:                                ; preds = %incinvertfor.body8.i, %invertfor.cond.cleanup7.i
; CHECK-NEXT:   %"x'de.i.1" = phi double [ %"x'de.i.0", %invertfor.cond.cleanup7.i ], [ %18, %incinvertfor.body8.i ]
; CHECK-NEXT:   %"iv1'ac.i.0" = phi i64 [ %times, %invertfor.cond.cleanup7.i ], [ %20, %incinvertfor.body8.i ]
; CHECK-NEXT:   %"arrayidx'ipg_unwrap.i" = getelementptr inbounds double, double* %".cast'ipc_unwrap.i", i64 %"iv1'ac.i.0"
; CHECK-NEXT:   %17 = load double, double* %"arrayidx'ipg_unwrap.i", align 8
; CHECK-NEXT:   store double 0.000000e+00, double* %"arrayidx'ipg_unwrap.i", align 8
; CHECK-NEXT:   %18 = fadd fast double %"x'de.i.1", %17
; CHECK-NEXT:   %19 = icmp eq i64 %"iv1'ac.i.0", 0
; CHECK-NEXT:   br i1 %19, label %invertfor.body.i, label %incinvertfor.body8.i

; CHECK: incinvertfor.body8.i:                             ; preds = %invertfor.body8.i
; CHECK-NEXT:   %20 = add nsw i64 %"iv1'ac.i.0", -1
; CHECK-NEXT:   br label %invertfor.body8.i

; CHECK: diffelist_creator.exit:                           ; preds = %invertfor.body.i
; CHECK-NEXT:   call void @free(i8* nonnull %malloccall.i) #4
; CHECK-NEXT:   call void @free(i8* nonnull %malloccall7.i) #4
; CHECK-NEXT:   call void @free(i8* nonnull %malloccall14.i) #4
; CHECK-NEXT:   call void @free(i8* nonnull %malloccall20.i) #4
; CHECK-NEXT:   ret double %18
; CHECK-NEXT: }

; CHECK: define internal void @diffesum_list(%struct.n* noalias readonly %node, %struct.n* %"node'", i64 %times, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %cmp18 = icmp eq %struct.n* %node, null
; CHECK-NEXT:   br i1 %cmp18, label %invertentry, label %for.cond1.preheader

; CHECK: for.cond1.preheader:                              ; preds = %entry, %for.cond.cleanup4
; CHECK-NEXT:   %0 = phi i8* [ %11, %for.cond.cleanup4 ], [ null, %entry ]
; CHECK-NEXT:   %iv = phi i64 [ %iv.next, %for.cond.cleanup4 ], [ 0, %entry ]
; CHECK-NEXT:   %1 = phi %struct.n* [ %"'ipl2", %for.cond.cleanup4 ], [ %"node'", %entry ]
; CHECK-NEXT:   %val.020 = phi %struct.n* [ %14, %for.cond.cleanup4 ], [ %node, %entry ]
; CHECK-NEXT:   %iv.next = add nuw nsw i64 %iv, 1
; CHECK-NEXT:   %2 = and i64 %iv.next, 1
; CHECK-NEXT:   %3 = icmp ne i64 %2, 0
; CHECK-NEXT:   %4 = call i64 @llvm.ctpop.i64(i64 %iv.next) #4, !range !31
; CHECK-NEXT:   %5 = icmp ult i64 %4, 3
; CHECK-NEXT:   %6 = and i1 %5, %3
; CHECK-NEXT:   br i1 %6, label %grow.i, label %__enzyme_exponentialallocation.exit

; CHECK: grow.i:                                           ; preds = %for.cond1.preheader
; CHECK-NEXT:   %7 = call i64 @llvm.ctlz.i64(i64 %iv.next, i1 true) #4, !range !32
; CHECK-NEXT:   %8 = sub nuw nsw i64 64, %7
; CHECK-NEXT:   %9 = shl i64 8, %8
; CHECK-NEXT:   %10 = call i8* @realloc(i8* %0, i64 %9) #4
; CHECK-NEXT:   br label %__enzyme_exponentialallocation.exit

; CHECK: __enzyme_exponentialallocation.exit:              ; preds = %for.cond1.preheader, %grow.i
; CHECK-NEXT:   %11 = phi i8* [ %10, %grow.i ], [ %0, %for.cond1.preheader ]
; CHECK-NEXT:   %12 = bitcast i8* %11 to %struct.n**
; CHECK-NEXT:   %13 = getelementptr inbounds %struct.n*, %struct.n** %12, i64 %iv
; CHECK-NEXT:   store %struct.n* %1, %struct.n** %13, align 8, !invariant.group !33
; CHECK-NEXT:   br label %for.body5

; CHECK: for.cond.cleanup4:                                ; preds = %for.body5
; CHECK-NEXT:   %"next'ipg" = getelementptr inbounds %struct.n, %struct.n* %1, i64 0, i32 1
; CHECK-NEXT:   %next = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 1
; CHECK-NEXT:   %"'ipl2" = load %struct.n*, %struct.n** %"next'ipg", align 8, !tbaa !7
; CHECK-NEXT:   %14 = load %struct.n*, %struct.n** %next, align 8, !tbaa !7
; CHECK-NEXT:   %cmp = icmp eq %struct.n* %14, null
; CHECK-NEXT:   br i1 %cmp, label %invertfor.cond.cleanup4, label %for.cond1.preheader

; CHECK: for.body5:                                        ; preds = %for.body5, %__enzyme_exponentialallocation.exit
; CHECK-NEXT:   %iv1 = phi i64 [ %iv.next2, %for.body5 ], [ 0, %__enzyme_exponentialallocation.exit ]
; CHECK-NEXT:   %iv.next2 = add nuw nsw i64 %iv1, 1
; CHECK-NEXT:   %exitcond = icmp eq i64 %iv1, %times
; CHECK-NEXT:   br i1 %exitcond, label %for.cond.cleanup4, label %for.body5

; CHECK: invertentry:                                      ; preds = %entry, %invertfor.cond1.preheader.preheader
; CHECK-NEXT:   ret void

; CHECK: invertfor.cond1.preheader.preheader:              ; preds = %invertfor.cond1.preheader
; CHECK-NEXT:   tail call void @free(i8* nonnull %11)
; CHECK-NEXT:   br label %invertentry

; CHECK: invertfor.cond1.preheader:                        ; preds = %invertfor.body5
; CHECK-NEXT:   %15 = icmp eq i64 %"iv'ac.0", 0
; CHECK-NEXT:   br i1 %15, label %invertfor.cond1.preheader.preheader, label %incinvertfor.cond1.preheader

; CHECK: incinvertfor.cond1.preheader:                     ; preds = %invertfor.cond1.preheader
; CHECK-NEXT:   %16 = add nsw i64 %"iv'ac.0", -1
; CHECK-NEXT:   br label %invertfor.cond.cleanup4

; CHECK: invertfor.cond.cleanup4:                          ; preds = %for.cond.cleanup4, %incinvertfor.cond1.preheader
; CHECK-NEXT:   %"iv'ac.0" = phi i64 [ %16, %incinvertfor.cond1.preheader ], [ %iv, %for.cond.cleanup4 ]
; CHECK-NEXT:   %17 = getelementptr inbounds %struct.n*, %struct.n** %12, i64 %"iv'ac.0"
; CHECK-NEXT:   br label %invertfor.body5

; CHECK: invertfor.body5:                                  ; preds = %incinvertfor.body5, %invertfor.cond.cleanup4
; CHECK-NEXT:   %"iv1'ac.0" = phi i64 [ %times, %invertfor.cond.cleanup4 ], [ %22, %incinvertfor.body5 ]
; CHECK-NEXT:   %18 = load %struct.n*, %struct.n** %17, align 8, !invariant.group !33
; CHECK-NEXT:   %"values'ipg_unwrap" = getelementptr inbounds %struct.n, %struct.n* %18, i64 0, i32 0
; CHECK-NEXT:   %"'ipl_unwrap" = load double*, double** %"values'ipg_unwrap", align 8, !tbaa !2
; CHECK-NEXT:   %"arrayidx'ipg_unwrap" = getelementptr inbounds double, double* %"'ipl_unwrap", i64 %"iv1'ac.0"
; CHECK-NEXT:   %19 = load double, double* %"arrayidx'ipg_unwrap", align 8
; CHECK-NEXT:   %20 = fadd fast double %19, %differeturn
; CHECK-NEXT:   store double %20, double* %"arrayidx'ipg_unwrap", align 8
; CHECK-NEXT:   %21 = icmp eq i64 %"iv1'ac.0", 0
; CHECK-NEXT:   br i1 %21, label %invertfor.cond1.preheader, label %incinvertfor.body5

; CHECK: incinvertfor.body5:                               ; preds = %invertfor.body5
; CHECK-NEXT:   %22 = add nsw i64 %"iv1'ac.0", -1
; CHECK-NEXT:   br label %invertfor.body5
; CHECK-NEXT: }
