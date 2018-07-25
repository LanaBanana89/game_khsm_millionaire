require 'rails_helper'

RSpec.describe GameQuestion, type: :model do

  let(:game_question) do
    FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end

  context 'game status' do

    it 'correct .variants' do

      expect(game_question.variants).to eq( 'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3
                                          )
    end

    it 'correct .answer_correct?' do
      expect(game_question.answer_correct?('b')).to be_truthy
    end

    it 'correct .level and .text' do
      expect(game_question.text).to eq (game_question.question.text)
      expect(game_question.level).to eq (game_question.question.level)
    end

    it 'correct .correct_answer_key' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  context 'user helpers' do
    it 'correct audience_help' do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)
      expect(game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
    end

    it 'correct fifty_fifty_help' do
      expect(game_question.help_hash).not_to include(:fifty_fifty)

      game_question.add_fifty_fifty

      expect(game_question.help_hash).to include(:fifty_fifty)
      expect(game_question.help_hash[:fifty_fifty]).to include(game_question.correct_answer_key)
      expect(game_question.help_hash[:fifty_fifty].size).to eq(2)
    end

    it 'correct friend_call_help' do
      expect(game_question.help_hash).not_to include(:friend_call)

      # возьмем сначала подсказку 50/50, а затем звонок другу
      game_question.add_fifty_fifty
      game_question.add_friend_call

      # варианты, которые останутся после подсказки 50/50
      variants = game_question.help_hash[:fifty_fifty]

      expect(game_question.help_hash).to include(:friend_call)
      expect(game_question.help_hash[:friend_call]).to be_an_instance_of(String)
      expect(game_question.help_hash[:friend_call]).to include("считает, что это вариант")

      # проверяем, что строка содержит один из двух вариантов, которые остались после 50/50
      expect(game_question.help_hash[:friend_call]).to include(variants[0].upcase).or include(variants[1].upcase)
    end
  end

  context 'check methods of game_question' do
    it 'correct .help_hash' do
      # на фабрике у нас изначально хэш пустой
      expect(game_question.help_hash).to eq({})

      # добавляем пару ключей
      game_question.help_hash[:some_key1] = 'blabla1'
      game_question.help_hash['some_key2'] = 'blabla2'

      # сохраняем модель и ожидаем сохранения хорошего
      expect(game_question.save).to be_truthy

      # загрузим этот же вопрос из базы для чистоты эксперимента
      gq = GameQuestion.find(game_question.id)

      # проверяем новые значение хэша
      expect(gq.help_hash).to eq({some_key1: 'blabla1', 'some_key2' => 'blabla2'})
    end
  end
end

