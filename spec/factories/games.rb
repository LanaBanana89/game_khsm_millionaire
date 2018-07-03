FactoryGirl.define do
  factory :game do
    # связь с юзером
    association :user

    # игра только начата
    finished_at nil
    current_level 0
    is_failed false
    prize 0

    factory :game_with_questions do
      after(:build) do  |game|
        15.times do |i|
          q = create(:question, level: i)
          create(:game_question, game: game, question: q)
        end
      end
    end
  end
end
