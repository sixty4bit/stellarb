class ChangeOnboardingStepDefaultToHamburgerIntro < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :onboarding_step, from: "profile_setup", to: "hamburger_intro"
  end
end
