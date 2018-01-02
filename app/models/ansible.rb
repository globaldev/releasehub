class Ansible < ActiveRecord::Base
  self.primary_key = "name"
  self.table_name = "applications"

  def self.get_project(env, project)
    establish_connection("ansible_#{env}".to_sym)
    self.where(name: project).first
  end

  def self.update_sha(env, project_name, new_sha)
    project = get_project(env.name, project_name)
    return true if project.previous_sha == new_sha # already updated
    project.previous_sha = project.sha
    project.sha = new_sha
    project.save
  end

  def self.rollback_sha(env, project_name)
    project = get_project(env.name, project_name)
    prev_sha = project.previous_sha
    project.previous_sha = project.sha
    project.sha = prev_sha
    project.save
  end
end
