require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do

  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  context 'Anon' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id

      # код ответа 302 - перенаправление на другую страницу(т.е. на страницу регистрации)
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #create' do

      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game)
      expect(game).to be_nil

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #answer' do
      put :answer, id: game_w_questions.id, letter: ['a', 'b', 'c', 'd'].sample

      game = assigns(:game)

      # код ответа 302 - перенаправление на другую страницу(т.е. на страницу регистрации)
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #take_money' do
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)

      # код ответа 302 - перенаправление на другую страницу(т.е. на страницу регистрации)
      expect(response.status).to eq 302
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end
  end

  # группы тестов на экшены контроллеров, доступных залогиненным пользователям
  context 'Usual user' do
    before(:each) do
      sign_in user
    end

    it 'creates game' do
      generate_questions(60)

      post :create

      game = assigns(:game)

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show')
    end

    # проверка, что пользовтеля посылают из чужой игры
    it '#show alien game' do
      # создаем новую игру, юзер не прописан, будет создан фабрикой новый
      alien_game = FactoryGirl.create(:game_with_questions)

      # пробуем зайти на эту игру текущий залогиненным user
      get :show, id: alien_game.id

      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'answer correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    it 'wrong answer' do
      answers = ['a', 'b', 'c', 'd']
      answers.delete('d')
      put :answer, id: game_w_questions.id, letter: answers.sample

      game = assigns(:game)

      # проверяем, что в @game находится текущая наша игра game_w_questions
      expect(game).to eq(game_w_questions)

      # проверям статус игры
      expect(game.status).to eq(:fail)

      # код ответа 302 - перенаправление на другую страницу(т.е. на страницу регистрации)
      expect(response.status).to eq(302)

      # проверяем, что приложение перенаправляет пользователя на его профиль
      expect(response).to redirect_to(user_path(user))

      # проверям текст сообщения с правильным ответом
      expect(flash[:alert]).to eq("Правильный ответ: #{game_w_questions.current_game_question.correct_answer}. Игра закончена, ваш приз #{game_w_questions.prize} ₽")
    end

    # юзер берет деньги
    it 'takes money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)

      # пользователь изменился в базе, надо в коде перезагрузить!
      user.reload
      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    # юзер пытается создать новую игру, не закончив старую
    it 'try to create second game' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsey

      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game).to be_nil

      # и редирект на страницу старой игры
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    # тест на обработку помощи зала
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses fifty-fifty help' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)

      expect(response).to redirect_to(game_path(game))
      expect(flash[:info]).to eq("Вы использовали подсказку")
    end
  end
end
