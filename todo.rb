# frozen_string_literal: false

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

require 'pry'

helpers do
  def todos_finished(list)
    list[:todos].inject(0) do |sum, todo|
      sum += 1 if todo[:complete]
      sum
    end
  end

  def list_complete?(list)
    finished = todos_finished(list)
    !finished.zero? && (list[:todos].size == finished)
  end

  def todo_status(todo)
    'complete' if todo[:complete]
  end

  def list_status(list)
    'complete' if list_complete?(list)
  end

  def order_lists(lists)
    lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
  end

  def order_todos(todos)
    todos.sort_by { |todo| todo[:complete] ? 1 : 0 }
  end
end

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, escape_html: true
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

def find_list(list_id)
  @lists.each { |list| return list if list[:id] == list_id }

  session[:error] = 'Sorry, list could not be found.'
  redirect '/lists'
end

not_found do
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif @lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_item_id(@lists)
    @lists << { id: id, name: list_name, todos: [] }

    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Display list items
get '/lists/:id' do |id|
  @id = id.to_i
  @list = find_list(@id)
  @todos = @list[:todos]

  erb :id, layout: :layout
end

# Render list editing form
get '/lists/:id/edit' do |id|
  @id = id.to_i
  @list = find_list(@id)
  erb :edit_list, layout: :layout
end

# Edit list
post '/lists/:id' do |id|
  @list_name = params[:list_name].strip
  @id = id.to_i
  @list = find_list(@id)

  error = error_for_list_name(@list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = @list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do |id|
  name = find_list(id.to_i)[:name]
  list = find_list(id.to_i)
  @lists.delete list

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = "The list \"#{name}\" has been deleted."
    redirect '/lists'
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  return if (1..100).cover? name.size

  'Todo must be between 1 and 100 characters.'
end

# 
def next_item_id(items)
  max = items.map { |item| item[:id] }.max || 0
  max + 1
end

# Add a new todo to a list
post '/lists/:list_id/todos' do |list_id|
  todo = params[:todo].strip
  @list = find_list(list_id.to_i)

  error = error_for_todo(todo)
  if error
    session[:error] = error
    @id = list_id.to_i
    erb :id, layout: :layout
  else
    id = next_item_id(@list[:todos])
    @list[:todos] << { id: id, name: todo, complete: false }
    
    session[:success] = "#{todo} was added to the list!"
    redirect "/lists/#{list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do |list_id, todo_id|
  # have to find the right todo and delete it from the list.
  todos = find_list(list_id.to_i)[:todos]
  todos.delete_if { |todo| todo[:id] == todo_id.to_i }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted!'
    redirect "/lists/#{params[:list_id]}"
  end
end

# Update the completion status of a todo
post '/lists/:list_id/todos/:todo_id/complete' do |list_id, todo_id|
  state = params[:complete] == 'true'
  todos = find_list(list_id.to_i)[:todos]
  @todo = Hash.new
  todos.each do |item|
    @todo = item if item[:id] == todo_id.to_i
  end

  @todo[:complete] = state
  session[:success] = 'Todo has been updated.'

  redirect "/lists/#{list_id}"
end

# Completes all todos in a list
post '/lists/:list_id/complete-all' do |list_id|
  list = find_list(list_id.to_i)
  list[:todos].each { |todo| todo[:complete] = true }
  session[:success] = 'All todos have been accomplished!'

  redirect "/lists/#{list_id}"
end
