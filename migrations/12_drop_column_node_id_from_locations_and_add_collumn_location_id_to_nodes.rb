Sequel.migration do
  up do
    drop_column :locations, :node_id
    add_column :nodes, :location_id, Integer
  end

  down do
    drop_column :nodes, :location_id
    add_column :locations, :node_id, Integer
  end
end