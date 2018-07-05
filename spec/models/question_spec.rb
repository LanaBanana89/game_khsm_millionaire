require 'rails_helper'

RSpec.describe Question, type: :model do
  context "validation_check" do

    it { should validate_presence_of :text }

    it do
      FactoryGirl.create(:question)
      should validate_uniqueness_of(:text)
    end

    it { should validate_presence_of :level }

    it {should validate_inclusion_of(:level).in_range(0..14) }

    it { should allow_value(14).for(:level) }
    it { should_not allow_value(15).for(:level) }
  end
end
