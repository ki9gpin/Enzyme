; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -instsimplify -simplifycfg -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,instsimplify,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

@enzyme_dupnoneed = dso_local global i32 0, align 4

define dso_local double @f(double %x, i64 %arg) {
entry:
  %call = call noalias i8* @calloc(i64 8, i64 %arg)
  %0 = bitcast i8* %call to double*
  store double %x, double* %0, align 8
  %1 = load double, double* %0, align 8
  ret double %1
}

declare dso_local noalias i8* @calloc(i64, i64)

define dso_local double @df(double %x) {
entry:
  %x.addr = alloca double, align 8
  store double %x, double* %x.addr, align 8
  %0 = load i32, i32* @enzyme_dupnoneed, align 4
  %1 = load double, double* %x.addr, align 8
  %call = call double (i8*, ...) @__enzyme_fwdsplit(i8* bitcast (double (double,i64)* @f to i8*), metadata !"enzyme_nofree", i32 %0, double %1, double 1.000000e+00, i64 1, i8* null)
  ret double %call
}

declare dso_local double @__enzyme_fwdsplit(i8*, ...)

; TODO check correctness

; CHECK: define internal i8* @augmented_f(double %x, double %"x'", i64 %arg)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %call = call noalias i8* @calloc(i64 8, i64 %arg)
; CHECK-NEXT:   %0 = bitcast i8* %call to double*
; CHECK-NEXT:   store double %x, double* %0, align 8
; CHECK-NEXT:   ret i8* null
; CHECK-NEXT: }

; CHECK: define internal double @fwddiffef(double %x, double %"x'", i64 %arg, i8* %tapeArg)
; CHECK-NEXT: entry:
; CHECK:   %"call'mi" = call noalias nonnull i8* @calloc(i64 8, i64 %arg)
; CHECK-NEXT:   %"'ipc" = bitcast i8* %"call'mi" to double*
; CHECK-NEXT:   store double %"x'", double* %"'ipc", align 8
; CHECK-NEXT:   %[[i0:.+]] = load double, double* %"'ipc", align 8
; CHECK-NEXT:   ret double %[[i0]]
; CHECK-NEXT: }
