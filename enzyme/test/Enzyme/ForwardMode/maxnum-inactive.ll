; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -early-cse -simplifycfg -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,early-cse,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

; Function Attrs: noinline nounwind readnone uwtable
define double @tester(double %x, double %y) {
entry:
  %0 = tail call double @llvm.maxnum.f64(double %x, double %y)
  ret double %0
}

define double @test_derivative(double %x, double %y) {
entry:
  %0 = tail call double (double (double, double)*, ...) @__enzyme_fwddiff(double (double, double)* nonnull @tester, double %x, double 1.0, metadata !"enzyme_const", double %y)
  ret double %0
}

; Function Attrs: nounwind readnone speculatable
declare double @llvm.maxnum.f64(double, double)

; Function Attrs: nounwind
declare double @__enzyme_fwddiff(double (double, double)*, ...)


; CHECK: define internal double @fwddiffetester(double %x, double %"x'", double %y)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = fcmp fast olt double %x, %y
; CHECK-NEXT:   %1 = select {{(fast )?}}i1 %0, double %"x'", double 0.000000e+00
; CHECK-NEXT:   ret double %1
; CHECK-NEXT: }