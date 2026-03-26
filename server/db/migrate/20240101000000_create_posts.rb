class CreatePosts < ActiveRecord::Migration[7.2]
  def change
    create_table :posts do |t|
      t.text :body, null: false
      t.timestamps
    end
  end
end
