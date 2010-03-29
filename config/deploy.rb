set :application, "sarena.maycamp.com"
set :repository,  "git://github.com/valo/spoj0.git"

set :scm, :git
set :branch, "v0.2RC"
set :user, "maycamp"
set :home_path, "/home/maycamp"
set :deploy_to, File.join(home_path, application)
set :deploy_via, :remote_cache
set :use_sudo, false
set :database_name, "sarena"

role :web, application                          # Your HTTP server, Apache/etc
role :app, application                          # This may be the same as your `Web` server
role :db,  application, :primary => true # This is where Rails migrations will run

def read_db_config(file, env)
  YAML.load_file(file)[env]
end

def get_settings
  get(File.join(shared_path, "config/database.yml"), "tmp/database.yml")
  stage_db_settings = read_db_config("tmp/database.yml", "production")
  prod_db_settings = read_db_config("tmp/database.yml", "arena_production")
  FileUtils.rm "tmp/database.yml"
  
  [stage_db_settings, prod_db_settings]
end

def timestamp
  Time.now.utc.strftime("%Y%m%d%H%M%S")
end

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

namespace :sets do
  task :sync_local do
    local_backup = File.expand_path("tmp/sets")
    remote_loc = File.join(shared_path, "sets")
    FileUtils.mkdir_p local_backup
    system "rsync -azv -e ssh --delete #{user}@#{application}:#{remote_loc} #{local_backup}"
  end
end

namespace :db do
  task :symlink, :except => { :no_release => true } do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/sets #{release_path}/sets"
  end
  
  task :sync do
    stage_db_settings, prod_db_settings = get_settings
    run "mysqldump #{prod_db_settings["database"]} -h #{prod_db_settings["host"]} -u #{prod_db_settings["username"]} -p#{prod_db_settings["password"]} | mysql #{stage_db_settings["database"]} -u #{stage_db_settings["username"]} -p#{stage_db_settings["password"]} -h #{stage_db_settings["host"]}"
  end
  
  task :backup do
    stage_db_settings, prod_db_settings = get_settings
    backup_file = "#{shared_path}/backup_#{timestamp}.bz2"
    run "mysqldump #{prod_db_settings["database"]} -h #{prod_db_settings["host"]} -u #{prod_db_settings["username"]} -p#{prod_db_settings["password"]} | bzip2 > #{backup_file}"
    get backup_file, File.join("tmp", File.basename(backup_file))
    run "rm #{backup_file}"
  end
  
  task :sync_local do
    backup
    latest_backup = Dir["tmp/backup_*.bz2"].sort.last
    local_db_settings = read_db_config("config/database.yml", "development")
    system "bzcat #{latest_backup} | mysql #{local_db_settings["database"]} -u #{local_db_settings["username"]} -p #{local_db_settings["password"]}"
  end
end

after "deploy:finalize_update", "db:symlink"