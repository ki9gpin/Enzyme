; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false  -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme"  -enzyme-preopt=false -S | FileCheck %s

declare i32 @putchar(i32) 

; Function Attrs: nounwind readnone uwtable
define double @tester(double %x) {
entry:
  %tmp = call i32 @putchar(i32 32)
  %0 = tail call fast double @llvm.exp.f64(double %x)
  ret double %0
}

define double @test_derivative(double %x) {
entry:
  %0 = tail call double (double (double)*, ...) @__enzyme_autodiff(double (double)* nonnull @tester, double %x)
  ret double %0
}

; Function Attrs: nounwind readnone speculatable
declare double @llvm.exp.f64(double)

; Function Attrs: nounwind
declare double @__enzyme_autodiff(double (double)*, ...)

; CHECK: define internal { double } @diffetester(double %x, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %"'de" = alloca double, align 8
; CHECK-NEXT:   store double 0.000000e+00, double* %"'de", align 8
; CHECK-NEXT:   %"x'de" = alloca double, align 8
; CHECK-NEXT:   store double 0.000000e+00, double* %"x'de", align 8
; CHECK-NEXT:   %tmp = call i32 @putchar(i32 32) #1
; CHECK-NEXT:   br label %invertentry

; CHECK: invertentry:                                      ; preds = %entry
; CHECK-NEXT:   store double %differeturn, double* %"'de", align 8
; CHECK-NEXT:   %0 = load double, double* %"'de", align 8
; CHECK-NEXT:   store double 0.000000e+00, double* %"'de", align 8
; CHECK-NEXT:   %1 = call fast double @llvm.exp.f64(double %x)
; CHECK-NEXT:   %2 = fmul fast double %0, %1
; CHECK-NEXT:   %3 = load double, double* %"x'de", align 8
; CHECK-NEXT:   %4 = fadd fast double %3, %2
; CHECK-NEXT:   store double %4, double* %"x'de", align 8
; CHECK-NEXT:   %5 = load double, double* %"x'de", align 8
; CHECK-NEXT:   %6 = insertvalue { double } undef, double %5, 0
; CHECK-NEXT:   ret { double } %6
; CHECK-NEXT: }