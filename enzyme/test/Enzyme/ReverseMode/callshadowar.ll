; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -instsimplify -adce -simplifycfg -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,instsimplify,adce,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

; ModuleID = 'ode-unopt.ll'
source_filename = "ode.cpp"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define double @inner(double* %data) {
entry:
  %d = load double, double* %data, align 8
  %r = fadd double %d, %d
  ret double %r
}

define double @inner2(double* %data) {
entry:
  %d = load double, double* %data, align 8
  %r = fsub double %d, %d
  ret double %r
}

define double @sub(double* %in, i64 %v) {
entry:
  %a = alloca double (double*)*, i64 2, align 8
  store double (double*)* @inner, double (double*)** %a, align 8
  %a1 = getelementptr double (double*)*, double (double*)** %a, i64 1
  store double (double*)* @inner2, double (double*)** %a1, align 8
  %fa = getelementptr double (double*)*, double (double*)** %a, i64 %v
  %f = load double (double*)*, double (double*)** %fa, align 8
  %r = call double %f(double* %in)
  ret double %r
}

define void @outer(double* %in, i64 %v) {
entry:
  %r = call double @sub(double* %in, i64 %v)
  store double %r, double* %in, align 8
  ret void
}

define void @caller(double* %in, double* %d_in) {
entry:
  call void (...) @__enzyme_autodiff(void (double*, i64)* nonnull @outer, double* %in, double* %d_in, i64 0) 
  ret void
}

declare void @__enzyme_autodiff(...)

; CHECK: define internal { i8*, double } @augmented_sub(double* %in, double* %"in'", i64 %v)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca { i8*, double }
; CHECK-NEXT:   %1 = getelementptr inbounds { i8*, double }, { i8*, double }* %0, i32 0, i32 0
; CHECK-NEXT:   %a = alloca double (double*)*, i64 2, align 8
; CHECK-NEXT:   %"a'ai" = alloca double (double*)*, i64 2, align 8
; CHECK-NEXT:   %[[a3:.+]] = bitcast double (double*)** %"a'ai" to i8*
; CHECK-NEXT:   call void @llvm.memset.p0i8.i64(i8* nonnull dereferenceable(16) dereferenceable_or_null(16) %[[a3]], i8 0, i64 16, i1 false)
; CHECK-NEXT:   store double (double*)* bitcast ({ { i8*, double } (double*, double*)*, void (double*, double*, double, i8*)* }* @"_enzyme_reverse_inner'" to double (double*)*), double (double*)** %"a'ai", align 8
; CHECK-NEXT:   store double (double*)* @inner, double (double*)** %a, align 8
; CHECK-NEXT:   %"a1'ipg" = getelementptr double (double*)*, double (double*)** %"a'ai", i64 1
; CHECK-NEXT:   %a1 = getelementptr double (double*)*, double (double*)** %a, i64 1
; CHECK-NEXT:   store double (double*)* bitcast ({ { i8*, double } (double*, double*)*, void (double*, double*, double, i8*)* }* @"_enzyme_reverse_inner2'" to double (double*)*), double (double*)** %"a1'ipg", align 8
; CHECK-NEXT:   store double (double*)* @inner2, double (double*)** %a1, align 8
; CHECK-NEXT:   %"fa'ipg" = getelementptr double (double*)*, double (double*)** %"a'ai", i64 %v
; CHECK-NEXT:   %fa = getelementptr double (double*)*, double (double*)** %a, i64 %v
; CHECK-NEXT:   %"f'ipl" = load double (double*)*, double (double*)** %"fa'ipg", align 8
; CHECK-NEXT:   %f = load double (double*)*, double (double*)** %fa, align 8
; CHECK-NEXT:   %[[i3:.+]] = bitcast double (double*)* %f to i8*
; CHECK-NEXT:   %[[i4:.+]] = bitcast double (double*)* %"f'ipl" to i8*
; CHECK-NEXT:   %[[i5:.+]] = icmp eq i8* %[[i3]], %[[i4]]
; CHECK-NEXT:   br i1 %[[i5]], label %error.i, label %__enzyme_runtimeinactiveerr.exit

; CHECK: error.i:                                          ; preds = %entry
; CHECK-NEXT:   %[[i6:.+]] = call i32 @puts(i8* getelementptr inbounds ([79 x i8], [79 x i8]* @.str, i32 0, i32 0))
; CHECK-NEXT:   call void @exit(i32 1)
; CHECK-NEXT:   unreachable

; CHECK: __enzyme_runtimeinactiveerr.exit:                 ; preds = %entry
; CHECK-NEXT:   %[[i7:.+]] = bitcast double (double*)* %"f'ipl" to { i8*, double } (double*, double*)**
; CHECK-NEXT:   %[[i8:.+]] = load { i8*, double } (double*, double*)*, { i8*, double } (double*, double*)** %[[i7]]
; CHECK-NEXT:   %r_augmented = call { i8*, double } %[[i8]](double* %in, double* %"in'")
; CHECK-NEXT:   %subcache = extractvalue { i8*, double } %r_augmented, 0
; CHECK-NEXT:   store i8* %subcache, i8** %1
; CHECK-NEXT:   %r = extractvalue { i8*, double } %r_augmented, 1
; CHECK-NEXT:   %[[i9:.+]] = getelementptr inbounds { i8*, double }, { i8*, double }* %0, i32 0, i32 1
; CHECK-NEXT:   store double %r, double* %[[i9]]
; CHECK-NEXT:   %[[i10:.+]] = load { i8*, double }, { i8*, double }* %0
; CHECK-NEXT:   ret { i8*, double } %[[i10]]
; CHECK-NEXT: }
