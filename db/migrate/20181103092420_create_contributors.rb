class CreateContributors < ActiveRecord::Migration
  def change
    create_table :contributors do |t|
      t.belongs_to :project
      t.belongs_to :user
      t.timestamps
    end
  end
end
