; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme"  -enzyme-preopt=false -S | FileCheck %s

%struct.Gradients = type { double, double }

; Function Attrs: nounwind
declare %struct.Gradients @__enzyme_fwddiff(double (double)*, ...)

; Function Attrs: nounwind readnone uwtable
define double @tester(double %x) {
entry:
  %0 = tail call fast double @llvm.cos.f64(double %x)
  ret double %0
}

define %struct.Gradients @test_derivative(double %x) {
entry:
  %0 = tail call %struct.Gradients (double (double)*, ...) @__enzyme_fwddiff(double (double)* nonnull @tester, metadata !"enzyme_width", i64 2, double %x, double 0.000000e+00, double 1.000000e+00)
  ret %struct.Gradients %0
}

; Function Attrs: nounwind readnone speculatable
declare double @llvm.cos.f64(double)

; CHECK: define internal [2 x double] @fwddiffe2tester(double %x, [2 x double] %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call fast double @llvm.sin.f64(double %x)
; CHECK-NEXT:   %1 = fneg fast double %0
; CHECK-NEXT:   %2 = extractvalue [2 x double] %"x'", 0
; CHECK-NEXT:   %3 = fmul fast double %2, %1
; CHECK-NEXT:   %4 = insertvalue [2 x double] undef, double %3, 0
; CHECK-NEXT:   %5 = extractvalue [2 x double] %"x'", 1
; CHECK-NEXT:   %6 = fmul fast double %5, %1
; CHECK-NEXT:   %7 = insertvalue [2 x double] %4, double %6, 1
; CHECK-NEXT:   ret [2 x double] %7
; CHECK-NEXT: }