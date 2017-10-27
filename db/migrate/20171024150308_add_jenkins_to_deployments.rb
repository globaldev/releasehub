class AddJenkinsToDeployments < ActiveRecord::Migration
  def change
    add_column :deployments, :jenkins, :integer, :limit => 3
  end
end
