class Fleet < ActiveRecord::Base
  belongs_to :shipping_company
  has_many :vessel_types, :through => :ships, :uniq => true
  has_many :ships, foreign_key: "fleet_id", dependent: :destroy
  has_many :voyages, :through => :ships
  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }
  validates :shipping_company_id, presence: true
end
