class SitesController < ApplicationController
  before_filter :login_required, :except => [ :show ]
  helper_method :sort_column, :sort_direction

  layout 'application', :except => [ :map ]

  require 'csv'

  #AJAX Calls
  def linked
    @citation = Citation.find(session["citation"])
    @site = Site.find(params[:id])

    exists = @citation.sites.exists?(@site.id)

    if exists
      @citation.sites.delete(@site)
    else
      @citation.sites<<@site
    end

    render :update do |page|
      page.replace_html "site-#{ @site.id }", ""
      page.replace_html "linked", :partial => 'linked'
    end
  end

  def rem_citations_sites
    @citation = Citation.find(params[:id])
    @site = Site.find(params[:site])

    render :update do |page|
      @citation.sites.delete(@site)
      page.replace_html 'edit_citations_sites', :partial => 'edit_citations_sites'
    end
  end

  def edit_citations_sites

    @site = Site.find(params[:id])

    render :update do |page|
      if !params["citation"].nil?
        params["citation"][:id].each do |c|
          next if c.empty?
          @site.citations << Citation.find(c)
        end
      end
      page.replace_html 'edit_citations_sites', :partial => 'edit_citations_sites'
    end
  end

  def map 
    @site = Site.find(params[:id])
    respond_to do |format|
      format.html # map.html.erb

      format.xml  { render :xml => @site }
      format.csv  { render :csv => @site }
      format.json { render :json => @site }
    end
  end

  def autocomplete
    search_term = params[:term]

    # filter site list by citation(s)

    if session[:citation_id_list]

      sites = Site.in_all_citations(session[:citation_id_list])

    elsif session[:citation]
      @citation = Citation.find_by_id(session["citation"])
      sites = @citation.sites
    end

    # match against any portion of the sitename, city, state, or country
    match_string = '%' + search_term + '%'

    filtered_sites = sites.where("LOWER(sitename) LIKE LOWER(:match_string) OR LOWER(city) LIKE LOWER(:match_string) OR LOWER(state) LIKE LOWER(:match_string) OR LOWER(country) LIKE LOWER(:match_string)",
                                 match_string: match_string)

    if filtered_sites.size > 0 || search_term.size > 1
      sites = filtered_sites
      # else if there are no matches and the user has only typed one letter, just return everything
    end

    sites = sites.to_a.map do |item|
      {
        # show city, state, and country information in site suggestions, but only show sitename after selection
        label: "#{item.sitename.squish} (#{item.city.squish}, #{!(item.state.nil? || item.state.empty?) ? " #{item.state.squish}," : ""} #{item.country.squish})",
        value: item.sitename.squish
      }
    end


    # don't show rows where name is null or empty
    # TO-DO: eliminate these from the database and prevent them with a constraint
    sites.delete_if { |item| item.nil? || item.empty? }

    if sites.empty?
      sites = [ { label: "No matches", value: "" }]
    end

    respond_to do |format|
      format.json { render :json => sites }
    end
  end

  # GET /sites
  # GET /sites.xml
  def index
    if params[:format].nil? or params[:format] == 'html'
      @iteration = params[:iteration][/\d+/] rescue 1
      @citation = Citation.find_by_id(session["citation"])
      # We will list those already linked above those that are not, so remove them from the list.
      @sites = Site.minus_already_linked(@citation).sorted_order("#{sort_column('sites','sitename')} #{sort_direction}").search(params[:search]).paginate(
        :page => params[:page], 
        :per_page => params[:DataTables_Table_0_length]
      )
      log_searches(Site.minus_already_linked(@citation).search(params[:search]).to_sql)
    else
      @sites = Site.api_search(params)
      log_searches(Site.method(:api_search), params)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @sites }
      format.csv  { render :csv => @sites }
      format.json { render :json => @sites }
    end
  end

  # GET /sites/1
  # GET /sites/1.xml
  def show
    @site = Site.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @site }
      format.csv  { render :csv => @site }
      format.json  { render :json => @site }
    end
  end

  # GET /sites/new
  # GET /sites/new.xml
  def new
    @site = Site.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @site }
      format.csv  { render :csv => @site }
      format.json  { render :json => @site }
    end
  end

  # GET /sites/1/edit
  def edit
    @site = Site.find(params[:id])
  end

  # POST /sites
  # POST /sites.xml
  def create
    @site = Site.new(params[:site])

    @site.user = current_user

    respond_to do |format|
      if @site.save
        # if they have a citation selected the relationship should be auto created!
        if !session["citation"].nil?
          @site.citations << Citation.find(session["citation"])
        end
        flash[:notice] = 'Site was successfully created.'
        format.html { redirect_to( sites_url ) }
        format.xml  { render :xml => @site, :status => :created, :location => @site }
        format.csv  { render :csv => @site, :status => :created, :location => @site }
        format.json  { render :json => @site, :status => :created, :location => @site }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
        format.csv  { render :csv => @site.errors, :status => :unprocessable_entity }
        format.json  { render :json => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.xml
  def update
    @site = Site.find(params[:id])

    params[:site].delete("user_id")

    respond_to do |format|
      if @site.update_attributes(params[:site])
        flash[:notice] = 'Site was successfully updated.'
        format.html { redirect_to(:action => :edit) }
        format.xml  { head :ok }
        format.csv  { head :ok }
        format.json  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
        format.csv  { render :csv => @site.errors, :status => :unprocessable_entity }
        format.json  { render :json => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.xml
  def destroy
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to(sites_url) }
      format.xml  { head :ok }
      format.csv  { head :ok }
      format.json  { head :ok }
    end
  end

end
