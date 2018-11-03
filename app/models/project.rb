class Project < ActiveRecord::Base
  belongs_to :user
  attr_accessible  :description, :name, :user_id, :contributors_attributes
  has_many :contributors
  has_many :users, :through => :contributors

  accepts_nested_attributes_for :contributors, :allow_destroy => true

end
