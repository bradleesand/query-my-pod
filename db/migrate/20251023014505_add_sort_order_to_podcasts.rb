class AddSortOrderToPodcasts < ActiveRecord::Migration[8.0]
  def change
    add_column :podcasts, :sort_order, :string, default: 'desc'
  end
end
