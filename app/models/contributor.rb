class Contributor < ActiveRecord::Base
  # attr_accessible :title, :body
  attr_accessible  :project_id, :user_id

  belongs_to :project
  belongs_to :user
end
