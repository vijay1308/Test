class Task < ActiveRecord::Base
  belongs_to :project
  attr_accessible  :asigned_use_id, :description,  :name, :project_id, :status_type_id
end
