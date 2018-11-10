class Project < ActiveRecord::Base
  belongs_to :user
  attr_accessible  :description, :name, :user_id, :contributors_attributes
  has_many :contributors
  has_many :users, :through => :contributors
  has_many :tasks

  accepts_nested_attributes_for :contributors, :allow_destroy => true

  def get_chart_data 
    data = []
    todo = ['todo status', 'Todo status count']
    data << todo
    todos = self.tasks.group_by {|a| a.status_type_id}
    todos.each do |status, records|
      todo_data = []
      todo_data << status.to_s
      todo_data << records.count
      data << todo_data
    end
    data
  end

end
