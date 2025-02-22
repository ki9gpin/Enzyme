; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -sroa -instsimplify -simplifycfg -adce -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,sroa,instsimplify,simplifycfg,adce"  -enzyme-preopt=false -S | FileCheck %s

; Function Attrs: nounwind readnone willreturn
declare double @cabs([2 x double]) #7

; Function Attrs: nounwind readnone uwtable
define double @tester(double %x, double %y) {
entry:
  %agg0 = insertvalue [2 x double] undef, double %x, 0
  %agg1 = insertvalue [2 x double] %agg0, double %y, 1
  %call = call double @cabs([2 x double] %agg1)
  ret double %call
}

define double @test_derivative(double %x, double %y) {
entry:
  %0 = tail call double (double (double, double)*, ...) @__enzyme_autodiff(double (double, double)* nonnull @tester, double %x, double %y)
  ret double %0
}

; Function Attrs: nounwind
declare double @__enzyme_autodiff(double (double, double)*, ...)


; CHECK: define internal { double, double } @diffetester(double %x, double %y, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %agg0 = insertvalue [2 x double] undef, double %x, 0
; CHECK-NEXT:   %agg1 = insertvalue [2 x double] %agg0, double %y, 1
; CHECK-NEXT:   %0 = call fast double @cabs([2 x double] %agg1)
; CHECK-NEXT:   %1 = fdiv fast double %differeturn, %0
; CHECK-NEXT:   %2 = fmul fast double %x, %1
; CHECK-NEXT:   %3 = fmul fast double %y, %1
; CHECK-NEXT:   %4 = insertvalue { double, double } undef, double %2, 0
; CHECK-NEXT:   %5 = insertvalue { double, double } %4, double %3, 1
; CHECK-NEXT:   ret { double, double } %5
; CHECK-NEXT: }
