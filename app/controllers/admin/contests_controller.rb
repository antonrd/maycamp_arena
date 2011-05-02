require 'zip/zipfilesystem'

class Admin::ContestsController < Admin::BaseController
  def index
    @contests = Contest.paginate(:page => params[:page], :per_page => 20, :order => "end_time DESC")
  end
  
  def show
    redirect_to admin_contest_problems_path(params[:id])
  end
  
  def new
    @contest = Contest.new
  end
  
  def create
    @contest = Contest.new params[:contest]
    
    if @contest.save
      redirect_to :action => "index"
    else
      render :action => "new"
    end
  end
  
  def edit
    @contest = Contest.find(params[:id])
  end
  
  def update
    @contest = Contest.find(params[:id])
    @contest.attributes = params[:contest]
    
    if @contest.save
      flash[:notice] = "Състезанието е обновено успешно."
      redirect_to edit_admin_contest_path(@contest.id)
    else
      render :action => "edit"
    end
  end
  
  def destroy
    @contest = Contest.destroy(params[:id])
    
    redirect_to :action => "index"
  end
  
  def download_sources
    @contest = Contest.find(params[:id], :joins => { :runs => [ :user, :problem ] })
    @runs = @contest.runs.group_by(&:user)
    
    zip_file = "#{RAILS_ROOT}/tmp/#{@contest.latin_name}.zip"
    FileUtils.rm zip_file if File.exists?(zip_file)
    
    Zip::ZipFile.open(zip_file, Zip::ZipFile::CREATE) do |zip|
      @runs.each do |user, user_runs|

        zip.mkdir user.latin_name
        user_runs.group_by(&:problem).each do |problem, runs|
          
          zip.mkdir "#{user.login} - #{user.latin_name}/#{problem.latin_name}"
          runs.sort_by(&:created_at).each_with_index do |run, index|
            output_file = "#{user.latin_name}/#{problem.latin_name}/#{index + 1}.cpp"
            zip.file.open(output_file, "w") do |f|
              f.puts run.source_code
            end
            
            zip.get_entry(output_file).time = run.created_at
          end
          
        end
        
      end
    end
    
    send_file zip_file
  end
end
