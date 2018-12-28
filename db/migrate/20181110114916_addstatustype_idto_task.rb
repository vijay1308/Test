class AddstatustypeIdtoTask < ActiveRecord::Migration
  def change
    add_column :tasks, :status_type_id, :integer
  end
end
