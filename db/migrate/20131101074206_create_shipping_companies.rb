class CreateShippingCompanies < ActiveRecord::Migration
  def change
    create_table :shipping_companies do |t|
      t.string :name
      t.string :email
      t.string :address
      t.string :telephone
      t.boolean :enabled
      t.integer :country_id

      t.timestamps
    end
  end
end
