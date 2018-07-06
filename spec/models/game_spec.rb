require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user)}

  let(:current_question) { game_w_questions.current_game_question }

  context 'Game Factory' do
    it 'Game.create_game_for_user! new correct game' do
      generate_questions(60)

      game = nil
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(
        change(GameQuestion, :count).by(15).and(
        change(Question, :count).by(0)
        )
      )

      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основную логику
  context 'game mechanics' do
    it 'answer correct continues' do
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      expect(game_w_questions.current_level).to eq(level + 1)
      expect(game_w_questions.previous_game_question).to eq q
      expect(game_w_questions.current_game_question).not_to eq q

      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'take_money! finishes the game' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  # группа тестов на проверку статуса игры
  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  context 'game methods' do
    before(:each) do
      # берем игру и отвечаем правильно на текущий вопрос
      game_w_questions.answer_current_question!(current_question.correct_answer_key)
    end

    it '.previous_level' do
      expect(game_w_questions.previous_level).to eq(0)
      expect(game_w_questions.previous_level).to eq(current_question.level)
    end

    it '.current_game_question' do
      # проверяем, что текущий вопрос совпадает со вторым вопросом из массива вопросов game_question
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[1])

      # проверяем, что у текущего вопроса уровень стал равным еденице
      # и стал больше на один от предыдущего вопроса
      expect(game_w_questions.current_game_question.level).to eq(1)
      expect(game_w_questions.current_game_question.level).to eq(current_question.level + 1)
    end
  end

  context '.answer_current_question!' do
    it 'correct answer' do
      game_w_questions.answer_current_question!(current_question.correct_answer_key)

      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'wrong answer' do
      answers = ['a', 'b', 'c', 'd']
      answers.delete(current_question.correct_answer_key)

      game_w_questions.answer_current_question!(answers.sample)
      expect(game_w_questions.status).to eq(:fail)
      expect(game_w_questions.finished?).to be_truthy
    end

    it 'last correct answer(one million)' do
      15.times do
        game_w_questions.answer_current_question!(current_question.correct_answer_key)
      end

      expect(game_w_questions.finished?).to be_truthy
      expect(game_w_questions.status).to eq(:won)
    end

    it 'correct answer after time_out!' do
      game_w_questions.created_at = Time.now - 36.minutes
      game_w_questions.finished_at = Time.now

      game_w_questions.answer_current_question!(current_question.correct_answer_key)

      expect(game_w_questions.status).to eq(:timeout)
      expect(game_w_questions.finished?).to be_truthy
    end
  end
end


