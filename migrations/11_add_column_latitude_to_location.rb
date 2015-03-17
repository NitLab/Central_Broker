Sequel.migration do
  up do
    add_column :locations, :altitude, Float
    drop_column :locations, :latitude
    drop_column :locations, :longitude
    add_column :locations, :latitude, Float
    add_column :locations, :longitude, Float
  end

  down do
    drop_column :locations, :altitude
  end
end