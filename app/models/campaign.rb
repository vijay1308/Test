class Campaign < ApplicationRecord
  include DateFormater
  include ActionView::Helpers::NumberHelper

  # # Associations
  #belongs_to :agency, optional: true
  belongs_to :client_agency, optional: true
  belongs_to :client, optional: true
  belongs_to :status, optional: true
  belongs_to :ads_server, optional: true
  belongs_to :campaign_status, optional: true
  belongs_to :ca_sub_stage, optional: true
  belongs_to :next_step, class_name: "CaSubStage", foreign_key: :next_ca_sub_stage_id, optional: true

  belongs_to :first_contact, class_name: "ClientAgencyContact", foreign_key: :first_contact_id, optional: true #must change field name as well
  belongs_to :second_contact, class_name: "ClientContact", foreign_key: :second_contact_id, optional: true
  belongs_to :first_assignee, class_name: "User", foreign_key: :first_assignee_id, optional: true
  belongs_to :second_assignee, class_name: "User", foreign_key: :second_assignee_id, optional: true

  belongs_to :created_by_user, class_name: "User", foreign_key: :created_by, optional: true
  belongs_to :updated_by_user, class_name: "User", foreign_key: :updated_by, optional: true


  has_many :ca_assets, as: :objectable
  has_many :notifications, as: :notifiable

  has_many :ca_target_audiences, dependent: :destroy
  has_many :ta_campaigns, dependent: :destroy
  has_many :target_audiences, through: :ca_target_audiences
  has_many :ca_rfps, dependent: :destroy
  has_many :ca_budget_phases, dependent: :destroy
  has_many :publisher_vendors, through: :ca_rfps
  has_many :publishers, through: :publisher_vendors
  has_many :campaign_gsis, dependent: :destroy
  has_many :publisher_templates
  has_many :master_media_publishers, dependent: :destroy
  has_many :insertion_orders, dependent: :destroy
  has_many :publisher_insertion_orders, dependent: :destroy
  has_many :mmp_publishers, dependent: :destroy
  has_many :master_media_clients, dependent: :destroy
  has_many :mmp_versions, dependent: :destroy
  has_many :campaign_activities , dependent: :destroy
  has_many :campaign_important_details , dependent: :destroy
  has_many :important_details_chat_logs , dependent: :destroy
  has_many :add_specs
  has_many :sizmek_raws
  has_many :recommdations,  dependent: :destroy
  has_many :campaign_invoices, dependent: :destroy
  has_many :dcm_rows
  has_many :publisher_rows
  has_many :campaign_todos, dependent: :destroy
  has_many :teammate_campaign_todos, dependent: :destroy

  has_one :ca_budget, dependent: :destroy
  has_one :client_proposal, dependent: :destroy
  has_one :gsi_campaign_weightage, dependent: :destroy
  has_one :campaign_combined_report, dependent: :destroy
  
  #nested atributes
  accepts_nested_attributes_for :ca_budget, reject_if: proc { |attributes| attributes['gross_total_budget'].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :ca_budget_phases, reject_if: proc { |attributes| attributes['title'].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :ca_target_audiences, reject_if: proc { |attributes| attributes['target_audience_id'].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :ta_campaigns, :allow_destroy => true


  #validations
  validates :title, :start_date, :end_date, presence: true
  validates :client_id, presence: true
  #validates :start_date, :end_date, future: true, on: :create
  validates :end_date, after: :start_date
  #validates :budget, numericality: {greater_than_or_equal_to: 0}
  #validates_inclusion_of :priority, :in => [ "Urgent", "Urgentish", "To Do", "N/A" ]
  #validate :campaign_dates_valid?

  before_create :set_unique_key, :set_campaign_number

  # accessors
  attr_accessor :attachments
  attr_readonly :created_by #Field should not be updated after once added

  after_create :create_notification, :set_status
  after_update :create_notification

  CA_TITLES = {"campaign": "File Uploaded for Campaign", "mmp": "Documents Uploaded For mmps", "campaign_briefing": "Campaign Briefing PDF",
               "response": "RFP response uploaded", "rfp_pdf": "Rfp Pdf generated", "insertion_order_xls": "InsertionOrderXls Generated",
              "insertion_order_pdf": "InsertionOrderPdf Generated", "insertion_order_client_upload": "Client Uploaded response",
              "insertion_order_publisher": "Insertion Order generated for publisher", "insertion_order_publisher_upload": "Insertion Order reposnse upload by publisher",
              "client_proposal": "Client proposal uploaded", "mockups": "Upload mockups", "creative_assets": "creative assets uploaded",
              "background_info": "Background Info uploaded", "add_tags": "Add Tags uploaded", "screen_shots": "screen shots uploaded",
              "clientreportingdocument": 'Client Reporting Document'
            }

  
  scope :with_campaign, proc { |campaign_id|
    where('id IN (?)', campaign_id) if campaign_id.present?
  }

  scope :with_status, proc { |status_id|
    where('status_id IN (?)', status_id) if status_id.present?
  }

  scope :with_client, proc { |client_id|
    where('client_id IN (?)', client_id) if client_id.present?
  }

  scope :with_agency, proc { |agency_id|
    where('client_agency_id IN (?)', agency_id) if agency_id.present?
  }

  scope :with_user, proc { |user_id|
    where('first_assignee_id IN (?)', user_id) if user_id.present?
  }
  #has_paper_trail

  #enum status: [  :not_sent, :in_progress, :closed ,:canceled ]
#---- instance methods------------------
  def save_attachments(params, user_id=nil, title="campaign")
    records = []
    user_id = user_id || Current.user.try(:id)
    if !params[:attachments].blank?
      begin
        params[:attachments].each do |file|
          records << self.ca_assets.create(:asset_path => file, comments: params[:comments], user_id: user_id, title: title, approved: params[:from] == 'client')
        end 
      rescue Exception => e
        return false, e, records
      end
      return true, "success", records
    else
      return true, "success", records
    end
  end

  def get_campaign_name
    "#{client_agency.try(:title)} - #{client.try(:name)} - #{title}"
  end

  def get_campaign_name_for_invoice
    "#{get_io_number} - #{client.try(:name)} - #{title} - #{Date.today.strftime('%b-%y')}"
  end

  def get_campaign_name_for_publisher_invoice
    "INV TBC - #{get_io_number} - #{client.try(:name)} - #{title} - #{Date.today.strftime('%b-%y')}"
  end

  def mockups
    ca_assets.where("lower(ca_assets.title) = 'mockups'")
  end

  def creative_assets
    ca_assets.where("lower(ca_assets.title) = 'creative_assets'")
  end

  def campaign_add_tags
    ca_assets.where("lower(ca_assets.title) = 'add_tags'")
  end

  def get_screen_shot
    ca_assets.where("lower(ca_assets.title) = 'screen_shots'")
  end

  def campaign_assets
    ca_assets.where("lower(ca_assets.title) = 'campaign'")
  end

  def background_info
    ca_assets.where("lower(ca_assets.title) = 'background_info'")
  end

  def media_plan_attachments
    ca_assets.where("(ca_assets.title) = 'MasterMediaClient'")
  end

  # upload mmp records
  def upload_mmp_documents(params, user_id=nil)
    records = []
    return false, "blank" if params.blank? || params[:attachments].blank?
    user_id ||= Current.user.try(:id)
    begin
      params[:attachments].each do |file|
        records << self.ca_assets.create(:asset_path => file, title: "mmp", comments: params[:comments], user_id: user_id)
      end
    rescue Exception => e
      return false, e, records
    end
    return true, "success", records
  end

  #all mmps which is uploaded
  def mmps_documents
    ca_assets.where("lower(ca_assets.title) = 'mmp'")
  end


  def duration
    "#{start_date.strftime('%d %B')} -  #{end_date.strftime('%d %B')}"
  end

  def net_budget
    budget
  end


  # return all publisher where we have created RFP with status
  def rfp_details
    records = []
    uniq_publisher_ids.each do |publisher_id|
      ca_rfp = self.ca_rfps.latest_rfps.where(publisher_id: publisher_id).last
      records << {publisher_id: publisher_id, rfp_id: ca_rfp.id, rfp_sent: ca_rfp.email_sent} if ca_rfp
    end
    records
  end

  def uniq_publisher_ids
    self.publisher_vendors.pluck(:id).uniq
  end

  def campaign_publishers
    self.publisher_vendors.pluck(:name).uniq
  end

  def campaign_actual_publishers
    publisher_ids = []
    publisher_ids << created_rfps.map(&:publisher_vendor).map(&:publisher_id).uniq
    publisher_ids << self.master_media_publishers.map(&:publisher_id).uniq
    publisher_ids << self.campaign_gsis.exclude_deleted.map(&:publisher_id).uniq
    Publisher.where(id: publisher_ids.flatten.uniq).pluck(:name).uniq

  end

  def uniq_punlishers
    publisher_through_venders = self.publishers.pluck(:id)
    publisher_through_gsis = self.campaign_gsis.pluck(:publisher_id)
    Publisher.includes(:publisher_gsi).where(id: publisher_through_venders + publisher_through_gsis)
  end

  #arrange json for api response if score present then need to send wotherwise publishers avaerage from publisher gsi table
  def all_publisher_gsis
    gsis = []
    fields = PublisherGsi.attribute_names.reject{|ps|["id", "created_at", "updated_at"].include?(ps)}
    uniq_punlishers.each do |publihser|
      publisher_gsi = publihser.publisher_gsi
      campaign_gsi = self.campaign_gsis.where(publisher_id: publihser.id).first
      unless campaign_gsi
        campaign_gsi = self.campaign_gsis.new()
        fields.each do |column_name|
          if ["past_campaign_performance", "publisher_id"].include?(column_name.to_s) 
            campaign_gsi.send("#{column_name}=", publisher_gsi.send(column_name.to_sym))# if self.respond_to?(column_name.to_sym)
          else
            campaign_gsi.send("#{column_name}=", 0)
          end
        end
        campaign_gsi.save
        campaign_gsi.update_publisher_gsis
      end
      gsis << campaign_gsi if !campaign_gsi.active_gsi?
    end
    gsis
  end

   #Create client_proposal or find latest one

  def first_or_create_client_proposal
    return client_proposal if client_proposal.present?
    ClientProposal.create(campaign_id: id, client_id: client_id, status: "Proposal Added")
  end

  def generate_rfp_pdf
    begin
      pdf = CampaignBriefing.new(self)
      pdf.draw_pdf
      f = Tempfile.new(['campaign_pdf', '.pdf'], :encoding => 'ascii-8bit')
      f.binmode
      f.write pdf.render
      ca_asset = self.campaign_briefing_pdf
      ca_asset = self.ca_assets.new unless ca_asset
      ca_asset.asset_path = f
      ca_asset.title = "campaign_briefing"
      ca_asset.save!
      f.unlink
      return true, ca_asset
    rescue Exception => e
      return false, e
    end
  end

  def campaign_briefing_pdf
    ca_assets.where(title: "campaign_briefing").first
  end


  def is_cancelled?
    self.status_id == 3
  end

  # for json responce
  def sent_rpfs
    publishers = {}
    publisher_and_venders = sent_rpfs_recorfds.each do |rfp|
      pub_id = rfp.publisher_vendor.publisher_id
      publishers[pub_id] = [] if publishers[pub_id].blank?
      publishers[pub_id] << {publisher_vendor_id: rfp.publisher_vendor_id, ca_rfp_id: rfp.id}
    end
    json_records = []
    publishers.each do |publisher_id, vendor_rfps|
      temp = {}
      temp[:publisher] = Publisher.find(publisher_id)
      temp[:publisher_vendors] = []
      vendor_rfps.each do |vendor_rfp|
        temp[:publisher_vendors] << {publisher_vendor: PublisherVendor.find(vendor_rfp[:publisher_vendor_id]), rfp: CaRfp.find(vendor_rfp[:ca_rfp_id])}
      end
      json_records << temp
    end
    json_records
    # if publisher_vendor_ids.blank?
    #   render json: {message: "No records"}, status: :unprocessable_entity
    #   return
    # end
    # json_records = []
    # publishers = Publisher.joins(:publisher_vendors).where("publisher_vendors.id IN(?)", publisher_vendor_ids)
    # publishers.each do |publisher|
    #   temp = {}
    #   temp[:publisher] = publisher
    #   temp[:publisher_vendors] = publisher.publisher_vendors.where("id IN(?)", publisher_vendor_ids)
    #   json_records << temp
    # end
  end

  def sent_rpfs_recorfds
    ca_rfps.exclude_deleted.email_sent.joins(publisher_vendor: :publisher)
  end

  def created_rfps
    ca_rfps.exclude_deleted.joins(publisher_vendor: :publisher)
  end

  #return all objects for mmp
  def master_media_plans
    records = []  
    publisher_vendor_ids = created_rfps.map(&:publisher_vendor_id).uniq
    publisher_ids = self.master_media_publishers.map(&:publisher_id).uniq
    campaign_gsis_ids = self.campaign_gsis.exclude_deleted.map(&:publisher_id).uniq

    # rfps and without rfps publishers, need to send all
    rfp_publisher_ids = Publisher.joins(:publisher_vendors).where(publisher_vendors: {id: publisher_vendor_ids}).map(&:id).uniq
    publishers = Publisher.where(id: publisher_ids + campaign_gsis_ids + rfp_publisher_ids).order("id ASC")
    return records if publishers.blank?
    publishers.compact.each do |publisher|
      pub_mmps = self.master_media_publishers.includes(:publisher, :mm_pub_booking,:mm_pub_ad_serving,:mm_pub_delivery_datum,:mm_pub_forcast, :mm_pub_trafficking,:mm_pub_spend,:mm_pub_delivery_time_range,:mm_pub_total_delivery_plio).where(publisher_id: publisher.id).order("created_at ASC")
      mmp_records = []
      pub_json = {}
      pub_json[:publisher] = publisher.attributes
      pub_json[:publisher][:mmp_count] = pub_mmps.count
      if pub_mmps.count == 0 # For first load if no records saved in mmps
        pub_json[:publisher][:mmp_count] = 2
        pub_json[:publisher][:is_publisher_included] = true
        group_records = []
        group_records << add_blank_mmps(publisher.name, true) #parent
        group_records << add_blank_mmps(publisher.name) #child
        mmp_records << group_records
      else
        pub_json[:publisher][:is_publisher_included] = MmpPublisher.mmp_publishers_present?(id, publisher.id)
        mmps_grouped_rows = pub_mmps.group_by{|mmp|mmp.group_id}
        mmps_grouped_rows.sort.to_h.each do |group_id, mmps_rows|
          mmps_rows.sort_by!{|a| a.is_parent ? 0 : 1}# put is parent at top always
          group_records = []
          mmps_rows.each do |mmp|
            mmp_hash = {}
            mmp_hash[:mmp] = mmp.attributes
            mmp_hash[:mmp]["ca_budget_phase_id"] = mmp_hash[:mmp]["ca_budget_phase_id"].blank? ? (self.ca_budget_phases[0]['id']).to_i : mmp_hash[:mmp]["ca_budget_phase_id"].to_i
            mmp_hash[:mmp]["start_date"] = mmp_hash[:mmp]["start_date"].blank? ? std_date(self.ca_budget_phases[0]['start_date']) : std_date(mmp_hash[:mmp]["start_date"]) 
            mmp_hash[:mmp]["end_date"] = mmp_hash[:mmp]["end_date"].blank? ? std_date(self.ca_budget_phases[0]['end_date']) : std_date(mmp_hash[:mmp]["end_date"])
            mmp_hash[:mmp][:publisher_name] = mmp.publisher.try(:name)
            mmp_hash[:booking] = mmp.mm_pub_booking.as_json
            mmp_hash[:ad_serving] = mmp.mm_pub_ad_serving.as_json
            mmp_hash[:delivery_data] = mmp.mm_pub_delivery_datum.as_json
            mmp_hash[:forcast] = mmp.mm_pub_forcast.as_json
            mmp_hash[:trafficking] = mmp.mm_pub_trafficking
            if mmp.mm_pub_spend.blank?
              mmp_hash[:media_spend] = MmPubSpend.new(bought_net_percent: '10.00', com_percent: '10.00') 
            else
              mmp_hash[:media_spend] =  mmp.mm_pub_spend
              # if  mmp.mm_pub_spend.bought_net_percent.to_f > 0.0 
              #   mmp_hash[:media_spend][:bought_net_percent] = mmp.mm_pub_spend.bought_net_percent 
              # else
              #   mmp_hash[:media_spend][:bought_net_percent] = '10.00'
              # end
              # if mmp.mm_pub_spend.com_percent.to_f > 0.0 
              #   mmp_hash[:media_spend][:com_percent] = mmp.mm_pub_spend.com_percent
              # else
              #   mmp_hash[:media_spend][:com_percent] = '10.00'
              # end
            end
            mmp_hash[:delivery_time_range] = mmp.mm_pub_delivery_time_range.blank? ? MmPubDeliveryTimeRange.new : mmp.mm_pub_delivery_time_range.as_json
            mmp_hash[:total_delivery_plio] = mmp.mm_pub_total_delivery_plio.blank? ? MmPubTotalDeliveryPlio.new : mmp.mm_pub_total_delivery_plio
            mmp_hash = format_mmp_records(mmp_hash)
            group_records << mmp_hash
          end
          mmp_records << group_records
        end
      end
      pub_json[:publisher][:mmps] = mmp_records
      records << pub_json
      
    end

    records
  end


  def format_mmp_records(mmp_hash)
    # formating
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'g_publisher_rate')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'g_agency_rate')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'g_sold_to_client')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'g_bought_from_publisher')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'margin_percent')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'discount_pub_agency')
    mmp_hash[:booking] = format_two_digit(mmp_hash[:booking], 'discount_agency_client')

    #for forcost
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'drop_of_percent')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'complete_of_percent')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'estimated_ctr_percent')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'estimated_cpc')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'click_to_percent')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'conversion_rate_percent')
    mmp_hash[:forcast] = format_two_digit(mmp_hash[:forcast], 'g_estimated_cpl')

    #ad serving
    mmp_hash[:ad_serving] = format_two_digit(mmp_hash[:ad_serving], 'ad_serving_cost')
    mmp_hash[:ad_serving] = format_two_digit(mmp_hash[:ad_serving], 'ad_serving_sales_price')
    mmp_hash[:ad_serving] = format_two_digit(mmp_hash[:ad_serving], 'ad_serving_margin_percent')

    # for delivery data
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'total_cost_client_gross')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'total_cost_client_net')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'get_cost_gross')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'get_cost_net')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'get_bonus_value_gross')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'get_bonus_value_net')
    mmp_hash[:delivery_data] = format_two_digit(mmp_hash[:delivery_data], 'total_ecpc')

   # for delivery_time_range
    #mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'delivery_time_range')
    mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'cost_to_client_gross')
    mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'cost_to_client_net')
    mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'bonus_value_gross')
    mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'bonus_value_net')
    mmp_hash[:delivery_time_range] = format_two_digit(mmp_hash[:delivery_time_range], 'ecpc')
    mmp_hash
  end

  def format_two_digit(_hash, field)
    return nil unless _hash
    _hash[field] = number_with_precision(_hash[field].to_f, precision: 2)
    _hash
  end

  def add_blank_mmps(publisher_name, is_parent=false)
    mmp_hash = {}
    mmp_hash[:mmp] = MasterMediaPublisher.new(is_parent: is_parent).attributes
    mmp_hash[:mmp]["ca_budget_phase_id"] = mmp_hash[:mmp]["ca_budget_phase_id"].blank? ? (self.ca_budget_phases[0]['id']).to_i : mmp_hash[:mmp]["ca_budget_phase_id"].to_i
    mmp_hash[:mmp]["start_date"] = mmp_hash[:mmp]["start_date"].blank? ? std_date(self.ca_budget_phases[0]['start_date']) : std_date(mmp_hash[:mmp]["start_date"]) 
    mmp_hash[:mmp]["end_date"] = mmp_hash[:mmp]["end_date"].blank? ? std_date(self.ca_budget_phases[0]['end_date']) : std_date(mmp_hash[:mmp]["end_date"])

    mmp_hash[:mmp][:publisher_name] = publisher_name
    mmp_hash[:mmp][:status]= "Y"
    mmp_hash[:booking] = MmPubBooking.new.as_json
    mmp_hash[:ad_serving] = MmPubAdServing.new.as_json
    mmp_hash[:delivery_data] = MmPubDeliveryDatum.new.as_json
    mmp_hash[:forcast] = MmPubForcast.new({drop_of_percent: '0.00', 
                                           complete_of_percent: '50.00',
                                           estimated_ctr_percent: '0.30',
                                           click_to_percent: '80.00',
                                           conversion_rate_percent: '15.00'}).as_json
    mmp_hash[:trafficking] = MmPubTrafficking.new.as_json
    mmp_hash[:media_spend] = MmPubSpend.new(bought_net_percent: '10.00', com_percent: '10.00').as_json
    mmp_hash[:delivery_time_range] = MmPubDeliveryTimeRange.new.as_json
    mmp_hash[:total_delivery_plio] = MmPubTotalDeliveryPlio.new.as_json
    mmp_hash = format_mmp_records(mmp_hash)
    mmp_hash
  end

  # publishers added from mmps page
  def publisher_mmps(publisher_ids)
    records = []
    return records if publisher_ids.blank?
    publishers = Publisher.where(id: publisher_ids)
    publishers.each do |publisher|
      mmp_records = []
      pub_json = {}
      pub_json[:publisher] = publisher.attributes
      pub_json[:publisher][:mmp_count] = 2
      pub_json[:publisher][:is_publisher_included] = true #MmpPublisher.mmp_publishers_present?(id, publisher.id)
      group_records = []
      group_records << add_blank_mmps(publisher.name, true) #parent
      group_records << add_blank_mmps(publisher.name) #child
      mmp_records << group_records
      pub_json[:publisher][:mmps] = mmp_records
      records << pub_json
    end
    records
  end

  # update mmp_publishers when mmps create or update
  def update_mmp_publishers(publishers)
    publishers.each do |publisher_id, is_included|
      if is_included
        mmp_publisher = self.mmp_publishers.where(publisher_id: publisher_id).present?
        self.mmp_publishers.create(publisher_id: publisher_id) unless mmp_publisher
      else
        self.mmp_publishers.where(publisher_id: publisher_id).destroy_all
      end
    end

  end


  def marked_publishers
    self.master_media_publishers
        .joins("INNER JOIN publishers  ON publishers.id = master_media_publishers.publisher_id
                INNER JOIN mmp_publishers ON mmp_publishers.publisher_id = master_media_publishers.publisher_id AND mmp_publishers.campaign_id = #{self.id}")
        .where("is_parent IS TRUE")
  end

  # def get_marked_publishers
  #   self.master_media_publishers.joins(publisher: :mmp_publishers).where("is_parent IS TRUE")
  # end

  # TODO need to improve SQL no need to get all groups
  # create or find master media clients for campaigns
  def find_or_create_mmcs(from_xls=false)
    # if master_media_clients.empty? # first time loaded
    #   mmps = master_media_publishers.joins(publisher: :mmp_publishers).where("is_parent IS TRUE")
    #   mmps.each do |mmp|
    #     create_or_update_mmc_record!(mmp)
    #   end
    # else # If anything added after master media plan added once
    #   added_mmp_ids = master_media_clients.pluck(:master_media_publisher_id)
    #   all_ids = master_media_publishers.joins(publisher: :mmp_publishers).where("is_parent IS TRUE").pluck(:id)
    #   (all_ids - added_mmp_ids).each do |mmp_id|
    #     create_or_update_mmc_record!(MasterMediaPublisher.find(mmp_id))
    #   end
    # end
    mmps = self.marked_publishers

    # removed those records those will be removed from mmps
    all_mmp_ids = mmps.pluck(:id)
    removed_mmps = master_media_clients.pluck(:master_media_publisher_id) - all_mmp_ids
    MasterMediaClient.where(id: removed_mmps).delete_all unless removed_mmps.blank?

    mmps.each do |mmp|
      create_or_update_mmc_record!(mmp)
    end
    if from_xls
      return campaing_mmcs_array
    else
      return campaign_mmcs
    end
  end

  # Already created mmcs
  def campaign_mmcs(params={})
    mmcs_records = []
    conditions = []
    unless params[:ca_budget_phase_id].blank? 
      conditions << "master_media_clients.ca_budget_phase_id = #{params[:ca_budget_phase_id]}"
    end
    master_media_clients.where(conditions.join(" AND ")).includes(publisher: [:publisher_gsi]).group_by{|mmc|mmc.publisher_id}.each_with_index do |(k, v), index|
      mmcs_records << ActiveModel::Serializer::CollectionSerializer.new(v, serializer: V1::MasterMediaClientSerializer, mmc_date: params[:mmc_date]).as_json
    end
    mmcs_records
  end

  def campaing_mmcs_array
    mmcs_records = []
    master_media_clients.group_by{|mmc|mmc.publisher_id}.each_with_index do |(k, v), index|
      mmcs_records << v
    end
    mmcs_records
  end

  # Create update mmcs
  def create_or_update_mmc_record!(mmp)
    mmc = self.master_media_clients.where(master_media_publisher_id: mmp.id).first
    #return if mmc && mmc.created_at >= mmp.updated_at
    mmc = self.master_media_clients.new(master_media_publisher_id: mmp.id) if mmc.blank?
    mmc.publisher_name = mmp.publisher.name
    mmc.publisher_id = mmp.publisher_id
    mmc.category_name = mmp.category.try(:name) || mmp.category_name
    mmc.site_or_product = mmp.products
    mmc.placements = mmp.placements
    mmc.device_targeting = mmp.device_targeting_name || mmp.device_target.try(:name)
    mmc.creative_type = mmp.creative_type.try(:name) || mmp.creative_type_name
    mmc.creative_size = mmp.creative_size_name
    mmc.creative_size_id = mmp.creative_size.try(:id) || mmp.creative_size_id
    mmc.creative_deadline = mmp.mm_pub_trafficking.try(:creative_delivery_dead_line)
    mmc.buy_type = mmp.mm_pub_booking.try(:buy_type).try(:name)
    mmc.publisher_rate = mmp.mm_pub_booking.try(:g_publisher_rate)
    mmc.agency_rate = mmp.mm_pub_booking.try(:g_agency_rate)
    mmc.start_date = mmp.start_date
    mmc.end_date = mmp.end_date
    mmc.impressions = mmp.mm_pub_forcast.try(:impressions)
    mmc.click_estimates = mmp.mm_pub_forcast.try(:clicks)
    mmc.total_cost_gross = mmp.mm_pub_delivery_datum.try(:total_cost_client_gross)
    mmc.total_cost_net = mmp.mm_pub_delivery_datum.try(:total_cost_client_net)
    mmc.package_name =   mmp.mm_pub_trafficking.try(:package_name)
    mmc.placement_name = mmp.mm_pub_trafficking.try(:placement_name)
    mmc.master_media_publisher_id = mmp.id
    mmc.creative_name_id = mmp.creative_name_id
    mmc.creative_message = mmp.creative_message
    mmc.ca_budget_phase_id = mmp.ca_budget_phase_id
    mmc.net_rates = mmp.mm_pub_trafficking.try(:net_rates)
    mmc.publisher_code = mmp.mm_pub_trafficking.try(:publisher_code)
    mmc.classification = mmp.mm_pub_trafficking.try(:classification)
    mmc.volumn = mmp.mm_pub_booking.try(:volumn)
    mmc.discount_pub_agency = mmp.mm_pub_booking.try(:discount_pub_agency)
    mmc.discount_agency_client = mmp.mm_pub_booking.try(:discount_agency_client)
    mmc.g_sold_to_client = mmp.mm_pub_booking.try(:g_sold_to_client)
    mmc.g_bought_from_publisher = mmp.mm_pub_booking.try(:g_bought_from_publisher)
    mmc.margin_percent = mmp.mm_pub_booking.try(:margin_percent)
    mmc.drop_of_percent = mmp.mm_pub_forcast.try(:drop_of_percent)
    mmc.views = mmp.mm_pub_forcast.try(:views)
    mmc.complete_of_percent = mmp.mm_pub_forcast.try(:complete_of_percent)
    mmc.completed_views = mmp.mm_pub_forcast.try(:completed_views)
    mmc.estimated_ctr_percent = mmp.mm_pub_forcast.try(:estimated_ctr_percent)
    mmc.clicks = mmp.mm_pub_forcast.try(:clicks)
    mmc.estimated_cpc = mmp.mm_pub_forcast.try(:estimated_cpc)
    mmc.click_to_percent = mmp.mm_pub_forcast.try(:click_to_percent)
    mmc.landings = mmp.mm_pub_forcast.try(:landings)
    mmc.conversion_rate_percent = mmp.mm_pub_forcast.try(:conversion_rate_percent)
    mmc.leads = mmp.mm_pub_forcast.try(:leads)
    mmc.g_bought = mmp.mm_pub_spend.try(:g_bought)
    mmc.bought_net_percent = mmp.mm_pub_spend.try(:bought_net_percent)
    mmc.bought_net = mmp.mm_pub_spend.try(:bought_net)
    mmc.g_sold = mmp.mm_pub_spend.try(:g_sold)
    mmc.com_percent = mmp.mm_pub_spend.try(:com_percent)
    mmc.com_value= mmp.mm_pub_spend.try(:com_value)
    mmc.sold_net = mmp.mm_pub_spend.try(:sold_net)
    mmc.sold_net_excl_product  = mmp.mm_pub_spend.try(:sold_net_excl_product)
    mmc.g_value_rate_card = mmp.mm_pub_spend.try(:g_value_rate_card)
    mmc.ad_serving_cost  = mmp.mm_pub_ad_serving.try(:ad_serving_cost)
    mmc.ad_serving_sales_price = mmp.mm_pub_ad_serving.try(:ad_serving_sales_price)
    mmc.ad_serving_margin_percent = mmp.mm_pub_ad_serving.try(:ad_serving_margin_percent)
    mmc.total_delivered_impressions = mmp.mm_pub_delivery_datum.try(:total_delivered_impressions)
    mmc.total_delivered_clicks = mmp.mm_pub_delivery_datum.try(:total_delivered_clicks)
    mmc.total_completion_video = mmp.mm_pub_delivery_datum.try(:total_completion_video)
    mmc.total_delivered_leads = mmp.mm_pub_delivery_datum.try(:total_delivered_leads)
    mmc.total_cost_client_gross = mmp.mm_pub_delivery_datum.try(:total_cost_client_gross)
    mmc.total_cost_client_net = mmp.mm_pub_delivery_datum.try(:total_cost_client_net)
    mmc.get_bonus_value_gross = mmp.mm_pub_delivery_datum.try(:get_bonus_value_gross)
    mmc.get_bonus_value_net = mmp.mm_pub_delivery_datum.try(:get_bonus_value_net)
    mmc.total_ecpc  = mmp.mm_pub_delivery_datum.try(:total_ecpc)
    mmc.delivered_imps = mmp.mm_pub_delivery_time_range.try(:delivered_imps)
    mmc.delivered_clicks = mmp.mm_pub_delivery_time_range.try(:delivered_clicks)
    mmc.completion_video = mmp.mm_pub_delivery_time_range.try(:completion_video)
    mmc.get_bonus_value_net = mmp.mm_pub_delivery_time_range.try(:get_bonus_value_net)
    mmc.delivered_leads = mmp.mm_pub_delivery_time_range.try(:delivered_leads)
    mmc.cost_to_client_gross = mmp.mm_pub_delivery_time_range.try(:cost_to_client_gross)
    mmc.cost_to_client_net = mmp.mm_pub_delivery_time_range.try(:cost_to_client_net)
    mmc.bonus_value_gross  = mmp.mm_pub_delivery_time_range.try(:bonus_value_gross)
    mmc.bonus_value_net = mmp.mm_pub_delivery_time_range.try(:bonus_value_net)
    mmc.ecpc = mmp.mm_pub_delivery_time_range.try(:ecpc)
    mmc.save!
  end


  def generate_insertion_order_without_doc(params)
    user_id = params[:current_user_id]
    msg, status = nil, false
    begin
      version_number = get_last_published_version.version_number
      insertion_order = self.insertion_orders.new(version_number: version_number, order_number: "IN#{InsertionOrder.count + 300000}")
      insertion_order.comments = "Insertion order created"
      insertion_order.generated_by = user_id
      if insertion_order.save!
        msg, status = true, "success"
      else
        msg, status = false, insertion_order.error_messages
      end

      if status
        self.marked_publishers.group_by{|a|a.publisher_id}.each do |publisher_id, records|
          insertion_order_pub = self.publisher_insertion_orders.new(version_number: version_number,
                 order_number: insertion_order.order_number,
                 publisher_id: publisher_id)
          insertion_order_pub.comments = "Insertion order created"
          insertion_order_pub.generated_by = user_id
          insertion_order_pub.save
        end
      end

    rescue Exception => e
      msg, status = false, e
    end
    return msg, status
  end

  # # this method now assume we have a insertion order and it just create pdf and xls 
  # and attached with those records
  def generate_insertion_order(params)
    user_id = params[:current_user_id]
    msg, status = nil, false
    begin

      version_number = get_last_published_version.version_number
      #params need to be send with name io_template_id
      io_template = InsertionOrderTemplate.find(params[:io_template_id])
      
      pdf = InsertionOrderPdf.new(self, version_number, io_template)
      #pdf.draw_pdf
      f = Tempfile.new(['InsertionOrderPdf', '.pdf'], :encoding => 'ascii-8bit')
      f.binmode
      f.write pdf.render
      ## changes at 19/03/18 by ansar as we need to create PDF and while send PDF
      ## insertion_order = self.insertion_orders.new(version_number: version_number, order_number: "IN#{InsertionOrder.count + 300000}")
      insertion_order = self.get_last_insertion_order
      # io_xls = InsertionOrderXls.new(self)
      # xls_file = io_xls.generate_xls_temp_file
      insertion_order.comments = "Insertion order created"
      insertion_order.generated_by = user_id
      if insertion_order.save!
        # insertion_order.ca_assets.create(:asset_path => xls_file, title: "insertion_order_xls", user_id: user_id)
        insertion_order.ca_assets.create(:asset_path => f, title: "insertion_order_pdf", user_id: user_id)
        # xls_file.unlink
        f.unlink
        msg, status = true, "success"
      else
        msg, status = false, insertion_order.error_messages
      end

      if status
        self.marked_publishers.group_by{|a|a.publisher_id}.each do |publisher_id, records|
          pdf = InsertionOrderPdf.new(self, version_number, io_template, records)
          f = Tempfile.new(['InsertionOrderPdfPublisher', '.pdf'], :encoding => 'ascii-8bit')
          f.binmode
          f.write pdf.render
      
          insertion_order_pub = self.get_last_insertion_order_pub(publisher_id)
          insertion_order_pub.comments = "Insertion order created"
          insertion_order_pub.generated_by = user_id
          insertion_order_pub = self.publisher_insertion_orders.new(version_number: version_number,
                 order_number: insertion_order.order_number,
                 publisher_id: publisher_id)
          if insertion_order_pub.save
            insertion_order_pub.ca_assets.create(:asset_path => f, title: "insertion_order_publisher", user_id: user_id)
            f.unlink
          end
        end
      end

    rescue Exception => e
      msg, status = false, e
    end
    return msg, status
  end

  def generate_final_client_insertion_order(params, client)
    msg, status = nil, false
    begin
      io_xls = FinalClientInsertionOrderXls.new(self, params)
      xls_file = io_xls.generate_xls_temp_file
      CaAsset.create(:asset_path => xls_file, title: "clientreportingdocument_#{self.id}", objectable_type: 'Client', objectable_id: client.id)
      xls_file.unlink
      msg, status = true, "success"
    rescue Exception => e
      msg, status = false, e
    end
    return msg, status
  end


  # generate master media clients
  def generate_master_media_clients(params, user_id)
    msg, status = nil, false
   # begin
      io_xls = MasterMediaXls.new(params,  self)
      xls_file = io_xls.generate_xls_temp_file
      self.ca_assets.where(title: "MasterMediaClient").delete_all
      ca_asset = self.ca_assets.create(:asset_path => xls_file, user_id: user_id, title: "MasterMediaClient")
      ExportRecord.where(export_type: "MasterMediaClient").last.try(:destroy)
      file_name = "Media-Plan" + '-' + self.client.try(:name).gsub(' ','-') + '-' + self.title.gsub(' ','-').gsub!(/[^0-9A-Za-z]/, '-') + '-' + Date.today.to_date.strftime("%d-%m-%y").to_s
      er = ExportRecord.create(path: xls_file, export_type: "MasterMediaClient", user_id: user_id, export_file_name: file_name)
      xls_file.unlink
      msg, status = true, "success", BASEURL + er.path.url
    # rescue Exception => e
    #   msg, status = false, e, nil
    # end
  end

  # Add versions of mmps and mmcs for a client also need to generate insertion order after publish
  def add_versions_of_mmcs_and_mmps(params={})
    user_id = params[:current_user_id]
    msg, status = nil, false
    user_id ||= Current.user.try(:id)
    version_number = 1
    last_version = get_last_published_version
    version_number = last_version.version_number + 1 if last_version
    mmp_version = self.mmp_versions.new(version_number: version_number)
    mmp_version.mmp_json = self.master_media_plans.to_json
    mmp_version.mmc_json = self.find_or_create_mmcs.to_json
    if mmp_version.save
     # as we need to user io template in pdf so just need to create records with no PDF and xls 
     #msg, status = self.generate_insertion_order(params)
     msg, status = self.generate_insertion_order_without_doc(params)
    end
    return msg, status
    #{mmcs: @campaign.find_or_create_mmcs}
  end

  def get_version_mmps(version_id)
    last_version = self.mmp_versions.where(id: version_id).first
    return [] if last_version.blank?
    JSON.parse(last_version.mmp_json)
  end

  def get_verion_mmcs(version_id)
    last_version = self.mmp_versions.where(id: version_id).first
    return [] if last_version.blank?
    JSON.parse(last_version.mmc_json)
  end

  # return last insertion order
  def get_last_insertion_order
    self.insertion_orders.where("version_number IS NOT NULL").last
  end

  # return last insertion order
  def get_last_insertion_order_pub(publisher_id)
    self.publisher_insertion_orders.where(publisher_id: publisher_id).last
  end


  # return last published record
  def get_last_published_version
    self.mmp_versions.last
  end

  def all_campaign_assets
    ca_asset_ids = []
    ca_asset_ids << self.ca_assets.pluck(:id)
    ca_asset_ids << self.ca_rfps.map{|rpf|rpf.ca_assets.pluck(:id)}
    ca_asset_ids << self.client_proposal.ca_assets.pluck(:id) if self.client_proposal
    #ca_asset_ids << self.insertion_orders.map{|ins|ins.ca_assets.pluck(:id)}
    ca_asset_ids = ca_asset_ids.flatten
    return [] if ca_asset_ids.blank?
    CaAsset.where(id: ca_asset_ids)
  end

  def log_details(user_id, action, description, objectable, new_data, old_data, extra={})
    self.campaign_activities.create!(action: action,
                                    description: description,
                                    objectable_id: objectable.id,
                                    objectable_type: objectable.class.name,
                                    old_data: old_data,
                                    new_data: new_data,
                                    user_id: user_id,
                                    changed_values: extra[:changed])
  end

  # return list of the vendors where RFP is available but not sent yet
  def not_send_rfp_vendors
    self.ca_rfps.where("rfp_sent_at IS NULL").map(&:publisher_vendor_id).uniq
  end

  # def insertion_order_pdf_record
  #   ca_assets.where(title: "InsertionOrderPdf").first
  # end

  def update_campaign_progress_status(current_code)
    current_stage = CaSubStage.where(code: current_code).first
    return false, "Currnet stage is not valid" if current_stage.blank?

    next_stage = CaSubStage.where(id: current_stage.id + 1).first
    return false, "Next stage is not valid" if next_stage.blank? && current_stage.code != "IN"

    status, message = set_ca_states(current_stage.code, next_stage.try(:code))  
  end

  def set_ca_states(current_code, next_code)
    status, message = false, "invalid data"
    current_stage_id = CaSubStage.where(code: current_code).first.try(:id)
    next_stage_id = CaSubStage.where(code: next_code).first.try(:id)
    #if (self.ca_sub_stage_id.to_i < current_stage_id.to_i && (self.next_ca_sub_stage_id.to_i < next_stage_id.to_i || current_code == "IN"))
      self.update_columns(ca_sub_stage_id: current_stage_id, next_ca_sub_stage_id:  next_stage_id)
      status, message = true, "Updated successfuly"
      self.reload
      if self.ca_sub_stage_id.to_i <= 6
        self.update_columns(status_id: 1)
      else
        self.update_columns(status_id: 2)
      end
    #end
    return status, message
  end

  def publisher_package_data
    # publisher_rows =  self.publisher_rows.select("publisher_rows.*, master_media_publishers.id AS mmp_id")
    #     .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = publisher_rows.package_name
    #                            INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
    #                     .where("master_media_publishers.is_parent IS TRUE")
    #                     .order('date asc').group_by{ |a| a.package_name }
    
    data = Hash.new { |hash, key| hash[key] = [] }

    mpt = self.master_media_publishers.where(is_parent: true).includes(:mm_pub_trafficking).map{|mmp| mmp.mm_pub_trafficking}
    self.publisher_rows.each do |pr|
      mpt.each do |mpt|
        if pr.package_name == mpt.package_name  
          data[mpt.id] << pr.id
        end
      end
    end

    publisher_records =[]
    data.each do |k, v| 
      pusblisher_grouped_records = self.publisher_rows.where(id: v)
       
      mmp = MmPubTrafficking.where(id: k).first
       
      mmp_data = MasterMediaPublisher.where(id: mmp.master_media_publisher_id).first
      pb = {}
      #pb[:date] = publisher_row.date
      pb[:served_impressions] = pusblisher_grouped_records.map{|a| a.delivered_impressions.to_i}.sum
      pb[:clicks] = pusblisher_grouped_records.map{|a| a.delivered_clicks.to_i}.sum
      #pb[:delivered_completed_views] = pusblisher_grouped_records.map{|a| a.delivered_completed_views.to_i}.sum
      #pb[:delivered_conversions] = pusblisher_grouped_records.map{|a| a.delivered_conversions.to_i}.sum
      pb[:bonus_value_gross_per_line] = pusblisher_grouped_records.map{|a| a.bonus_value_gross_per_line.to_i}.sum
      if mmp_data
        pb[:creative_size]  = mmp_data.creative_size_name
        pb[:publisher_name] = mmp_data.publisher.try(:name) if mmp_data.publisher
        pb[:buy_type]       = mmp_data.mm_pub_booking.buy_type.try(:name) if mmp_data.mm_pub_booking
        pb[:media_spend]    = mmp_data.mm_pub_spend
        pb[:site_name]      = mmp_data.products
        pb[:campaign_name]  = mmp_data.campaign.try(:title)
        pb[:package_name]   = mmp.try(:package_name)
        pb[:placement_name] = mmp.try(:placement_name)
      end

      publisher_records << pb
    end
    publisher_records
  end

  def arrange_publisher(params)
    conditions = []
    conditions << "publisher_rows.publisher_id = #{params[:publisher_id]}" if params[:publisher_id].present?
    if params[:start_date].present? && params[:end_date].present?
      publisher_rows = self.publisher_rows.where(conditions.join( "AND" )).where(date: (params[:start_date].to_date..params[:end_date].to_date)).select("distinct(publisher_rows.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = publisher_rows.package_name
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('date asc')
    else
      publisher_rows = self.publisher_rows.where(conditions.join( "AND" )).select("distinct(publisher_rows.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = publisher_rows.package_name
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('date asc')
    end
    publisher_row_records = []
    publisher_rows_grouped = publisher_rows.group_by {|a| a.date}
    publisher_rows_grouped.each do |date, publisher_rows_data|
      publisher = publisher_rows_data.first
      publisher_data = {}

      publisher_data[:campaign_id] = publisher.campaign_id
      publisher_data[:publisher_id] = publisher.publisher_id
      publisher_data[:package_name] = publisher.package_name
      publisher_data[:placement_name] = publisher.placement_name
     
      publisher_data[:date] = publisher.date
      publisher_data[:delivered_impressions] = publisher_rows_data.map{|a| a.delivered_impressions.to_i}.sum
      publisher_data[:delivered_clicks] = publisher_rows_data.map{|a| a.delivered_clicks.to_i}.sum
      publisher_data[:delivered_conversions] = publisher_rows_data.map{|a| a.delivered_conversions.to_i}.sum
      publisher_data[:delivered_completed_views] = publisher_rows_data.map{|a| a.delivered_completed_views.to_i}.sum
      publisher_row_records << publisher_data
    end
    publisher_row_records
  end



  def grouped_with_packaged
    # now get sizmek raws based on package name matched 
    #sizmek_raws = self.sizmek_raws.select("sizmek_raws.*,  master_media_publishers.* AS master_media_publishers_id")
        # .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = sizmek_raws.package_name
        #                        INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
        #                 .where("master_media_publishers.is_parent IS TRUE AND master_media_publishers.campaign_id = #{self.id}")
        #                 .order('date asc')#.group_by {|a| a.package_name}
    
    # sizmek_raws = self.sizmek_raws.order('date asc').group_by {|a|a.package_name}
    data = Hash.new { |hash, key| hash[key] = [] }

    mpt = self.master_media_publishers.where(is_parent: true).includes(:mm_pub_trafficking).map{|mmp| mmp.mm_pub_trafficking}
    self.sizmek_raws.each do |sr|
      mpt.each do |mpt|
        if sr.package_name == mpt.package_name  
          data[mpt.id] << sr.id
        end
      end
    end  
    sizmek_raws_records = arrange_simemek_data_bye_package_name(data)
    # return sizmek_raws_records
  end

  def get_sizmek_raws(params)
    if params[:start_date] && params[:end_date]
      sizmek_raws =  self.sizmek_raws.where(date: (params[:start_date].to_date..params[:end_date].to_date)).select("distinct(sizmek_raws.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = sizmek_raws.package_name
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('date asc').group_by {|a| a.date}
    else
      sizmek_raws = self.sizmek_raws.select("distinct(sizmek_raws.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = sizmek_raws.package_name
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('date asc').group_by {|a| a.date}
    end
    sizmek_raws_records = arrange_simemek_data_bye_date(sizmek_raws)
    return sizmek_raws_records
  end

  def arrange_simemek_data_bye_date(sizmek_raws)
    sizmek_raws_records =[]
      
    sizmek_raws.each do |grouped_by ,sizmek_raw_records| 
      sizmek_raw_records = sizmek_raw_records.uniq
      sizmek = {}
      sizmek_raw = sizmek_raw_records.first
       
      sizmek[:id] = sizmek_raw.id
      sizmek[:campaign_id] = sizmek_raw.campaign_id
      sizmek[:campaign_name] = sizmek_raw.campaign_name
      sizmek[:placement_id] = sizmek_raw.placement_id
      sizmek[:site_name] = sizmek_raw.site_name
      sizmek[:section_name] = sizmek_raw.section_name
      sizmek[:package_name] = sizmek_raw.package_name
      sizmek[:placement_name] = sizmek_raw.placement_name
      #sizmek[:ad_name] = sizmek_raw.ad_name
      #sizmek[:unit_size] = sizmek_raw.unit_size
      # sizmek[:ad_format] = sizmek_raw.ad_format
      # sizmek[:placment_classification1] = sizmek_raw.placment_classification1
      # sizmek[:placment_classification2] = sizmek_raw.placment_classification2
      # sizmek[:placement_start_date] = sizmek_raw.placement_start_date
      # sizmek[:placement_end_date] = sizmek_raw.placement_end_date
      # sizmek[:unit_cost] = sizmek_raw.unit_cost
      # sizmek[:cost_based_type] = sizmek_raw.cost_based_type
      sizmek[:date] = sizmek_raw.date
      # sizmek[:interactions] = sizmek_raw.interactions
      # sizmek[:video_started] = sizmek_raw.video_started
      # sizmek[:video_25_palyed_rate] = sizmek_raw.video_25_palyed_rate
      # sizmek[:video_50_played_rate] = sizmek_raw.video_50_played_rate
      # sizmek[:video_75_played_rate] = sizmek_raw.video_75_played_rate
      # sizmek[:video_fully_played] = sizmek_raw.video_fully_played
      # sizmek[:video_muted] = sizmek_raw.video_muted
      # sizmek[:video_paused] = sizmek_raw.video_paused
      # sizmek[:total_expansions] = sizmek_raw.total_expansions
      # sizmek[:video_paused] = sizmek_raw.video_paused

      sizmek[:served_impressions] = sizmek_raw_records.map(&:served_impressions).compact.sum
      sizmek[:clicks] = sizmek_raw_records.map(&:clicks).compact.sum
      sizmek[:total_media_cost] = sizmek_raw_records.map(&:total_media_cost).compact.sum
      # sizmek[:post_click_conversions] = sizmek_raw_records.map(&:post_click_conversions).compact.sum
      # sizmek[:post_impression_conversions] = sizmek_raw_records.map(&:post_impression_conversions).compact.sum
      sizmek[:total_conversions] = sizmek_raw_records.map(&:total_conversions).compact.sum
      sizmek[:bonus_value_gross_per_line] = sizmek_raw_records.map(&:bonus_value_gross_per_line).compact.sum
      sizmek[:ctr] = calculate_ctr(sizmek[:clicks], sizmek[:served_impressions])
      sizmek[:cvr] = calculate_cvr(sizmek[:clicks], sizmek[:total_conversions])
      sizmek_raws_records << sizmek
    end
    sizmek_raws_records
  end

  def arrange_simemek_data_bye_package_name(sizmek_raws)
    sizmek_raws_records =[]
    sizmek_raws.each do |k, v|
      sizmek_raw_records = self.sizmek_raws.where(id: v)
      sizmek = {}
      mmp = MmPubTrafficking.where(id: k).first
      mmp_data = MasterMediaPublisher.where(id: mmp.master_media_publisher_id, is_parent: true, campaign_id: self.id).first
      if mmp_data
        sizmek[:publisher_name] = mmp_data.publisher.try(:name) if mmp_data.publisher
        sizmek[:creative_size]  = mmp_data.creative_size_name
        sizmek[:buy_type]       = mmp_data.mm_pub_booking.buy_type.try(:name) if  mmp_data.mm_pub_booking
        sizmek[:media_spend]    = mmp_data.mm_pub_spend
        sizmek[:site_name]      = mmp_data.products
        sizmek[:campaign_name]  = mmp_data.campaign.try(:title)
        sizmek[:package_name]   = mmp.package_name
        sizmek[:placement_name] = mmp.placement_name
        sizmek[:campaign_id]    = mmp_data.campaign_id
      end
      sizmek[:served_impressions] = sizmek_raw_records.map(&:served_impressions).compact.sum
      sizmek[:clicks] = sizmek_raw_records.map(&:clicks).compact.sum
      sizmek[:total_media_cost] = sizmek_raw_records.map(&:total_media_cost).compact.sum
      sizmek[:total_conversions] = sizmek_raw_records.map(&:total_conversions).compact.sum
      sizmek[:bonus_value_gross_per_line] = sizmek_raw_records.map(&:bonus_value_gross_per_line).compact.sum
      sizmek[:ctr] = calculate_ctr(sizmek[:clicks], sizmek[:served_impressions])
      sizmek[:cvr] = calculate_cvr(sizmek[:clicks], sizmek[:total_conversions])
      sizmek_raws_records << sizmek
    end
    sizmek_raws_records
  end

  def calculate_ctr(clicks, served_impressions)
    begin
      ctr = ((clicks.to_f / served_impressions.to_f)*100).round(2)
      return ctr
    rescue Exception => e
      return 0.0
    end 
    
  end

  def calculate_cvr(clicks, total_conversions)
    begin
      cvr = ((total_conversions.to_f / clicks.to_f) * 100).round(2)
      return cvr 
    rescue Exception => e
      return 0.0
    end 
  end


  def grouped_with_package_name_dcm
    # now get dcm rows based on package name matched 
    # dcm_rows = self.dcm_rows.select("dcm_rows.*, master_media_publishers.id AS mmp_id")
    #     .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = dcm_rows.package_or_roadblock
    #                            INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
    #                     .where("master_media_publishers.is_parent IS TRUE")
    #                     .order('placement_date asc').group_by {|a|a.package_or_roadblock}
    # before 
    # dcm_rows = self.dcm_rows.order('placement_date asc').group_by {|a|a.package_or_roadblock}
    
    data = Hash.new { |hash, key| hash[key] = [] }

    mpt = self.master_media_publishers.where(is_parent: true).includes(:mm_pub_trafficking).map{|mmp| mmp.mm_pub_trafficking}
    self.dcm_rows.each do |dr|
      mpt.each do |mpt|
        if dr.package_or_roadblock == mpt.package_name  
          data[mpt.id] << dr.id
        end
      end
    end

    dcm_rows_records = arrange_dcm_row_data_bye_package(data)
    return dcm_rows_records
  end

  def get_dcm_rows(params)
    if params[:start_date] && params[:end_date]
      dcm_rows =  self.dcm_rows.where(placement_date: (params[:start_date].to_date..params[:end_date].to_date)).select("distinct(dcm_rows.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = dcm_rows.package_or_roadblock
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('placement_date asc').group_by {|a| a.placement_date}
    else
      dcm_rows = self.dcm_rows.select("distinct(dcm_rows.*),  master_media_publishers.id AS mmp_id")
        .joins("INNER JOIN mm_pub_traffickings ON mm_pub_traffickings.package_name = dcm_rows.package_or_roadblock
                               INNER JOIN master_media_publishers ON master_media_publishers.id = mm_pub_traffickings.master_media_publisher_id")
                        .where("master_media_publishers.is_parent IS TRUE").order('placement_date asc').group_by {|a| a.placement_date}
    end
    dcm_rows_records = arrange_dcm_row_data_bye_date(dcm_rows)
    return dcm_rows_records
  end

  def arrange_dcm_row_data_bye_date(dcm_rows)
     dcm_rows_data =[]
     dcm_rows.each do |grouped_by, dcm_rows_records|
      dcm_row = {}
      
      dcm_row_raw = dcm_rows_records.first
      dcm_row[:id] = dcm_row_raw.id
      dcm_row[:campaign_id] = dcm_row_raw.campaign_id
      
      dcm_row[:placement_start_date] = dcm_row_raw.placement_date
      dcm_row[:served_impressions] = dcm_rows_records.map{|a| a.impressions.to_i}.sum
      dcm_row[:clicks] = dcm_rows_records.map{|a| a.clicks.to_i}.sum
      dcm_row[:click_rate] = dcm_rows_records.map{|a| a.click_rate.to_i}.sum
      # dcm_row[:active_view_viewable_impressions] = dcm_row_raw.active_view_viewable_impressions
      # dcm_row[:active_view_measurable_impressions] = dcm_row_raw.active_view_measurable_impressions
      # dcm_row[:active_view_eligible_impressions] = dcm_row_raw.active_view_eligible_impressions
      dcm_row[:total_conversions] = dcm_row_raw.total_conversions
      # dcm_row[:video_completions] = dcm_row_raw.video_completions
      # dcm_row[:uncapped_cost_to_client_gross_per_line] = dcm_row_raw.uncapped_cost_to_client_gross_per_line
      # dcm_row[:uncapped_cost_to_client_gross_daily_sum_per_line] = dcm_row_raw.uncapped_cost_to_client_gross_daily_sum_per_line
      # dcm_row[:uncapped_cost_to_client_gross_daily_sum_cumulative] = dcm_row_raw.uncapped_cost_to_client_gross_daily_sum_cumulative
      # dcm_row[:over_under_planned_gross_daily_sum_cumulative] = dcm_row_raw.over_under_planned_gross_daily_sum_cumulative
      # dcm_row[:planned_cost_reached_daily_sum_cumulative] = dcm_row_raw.planned_cost_reached_daily_sum_cumulative
      # dcm_row[:exact_day_of_cost_reached_daily_sum_cumulative] = dcm_row_raw.exact_day_of_cost_reached_daily_sum_cumulative
      # dcm_row[:capped_cost_to_client_gross_per_line] = dcm_row_raw.capped_cost_to_client_gross_per_line
      dcm_row[:bonus_value_gross_per_line] = dcm_row_raw.bonus_value_gross_per_line
      dcm_row[:ctr] = calculate_ctr(dcm_row[:clicks], dcm_row[:impressions])
      dcm_row[:cvr] = calculate_cvr(dcm_row[:clicks], dcm_row[:total_conversions])

      dcm_rows_data << dcm_row
    end
    dcm_rows_data
  end

  def arrange_dcm_row_data_bye_package(dcm_rows)
     dcm_rows_data =[]
     dcm_rows.each do |k, v|
      dcm_row = {}
      dcm_rows_records = self.dcm_rows.where(id: v)
      dcm_row_raw = dcm_rows_records.first
      mmp = MmPubTrafficking.where(id: k).first
      mmp_data = MasterMediaPublisher.where(id: mmp.master_media_publisher_id, is_parent: true).first
      
      if mmp_data
        dcm_row[:publisher_name] = mmp_data.publisher.try(:name) if mmp_data.publisher
        dcm_row[:creative_size]  = mmp_data.creative_size_name
        dcm_row[:buy_type]       = mmp_data.mm_pub_booking.buy_type.try(:name) if  mmp_data.mm_pub_booking
        dcm_row[:media_spend]    = mmp_data.mm_pub_spend
        dcm_row[:site_name]      = mmp_data.products
        dcm_row[:campaign_name]  = mmp_data.campaign.try(:title)
        dcm_row[:package_name]   = mmp.package_name
        dcm_row[:placement_name] = mmp.placement_name
      end
      
      dcm_row[:placement_start_date] = dcm_row_raw.placement_date
      dcm_row[:served_impressions] = dcm_rows_records.map{|a| a.impressions.to_i}.sum
      dcm_row[:clicks] = dcm_rows_records.map{|a| a.clicks.to_i}.sum
      dcm_row[:click_rate] = dcm_rows_records.map{|a| a.click_rate.to_i}.sum
      # dcm_row[:active_view_viewable_impressions] = dcm_row_raw.active_view_viewable_impressions
      # dcm_row[:active_view_measurable_impressions] = dcm_row_raw.active_view_measurable_impressions
      # dcm_row[:active_view_eligible_impressions] = dcm_row_raw.active_view_eligible_impressions
      dcm_row[:total_conversions] = dcm_row_raw.total_conversions
      # dcm_row[:video_completions] = dcm_row_raw.video_completions
      # dcm_row[:uncapped_cost_to_client_gross_per_line] = dcm_row_raw.uncapped_cost_to_client_gross_per_line
      # dcm_row[:uncapped_cost_to_client_gross_daily_sum_per_line] = dcm_row_raw.uncapped_cost_to_client_gross_daily_sum_per_line
      # dcm_row[:uncapped_cost_to_client_gross_daily_sum_cumulative] = dcm_row_raw.uncapped_cost_to_client_gross_daily_sum_cumulative
      # dcm_row[:over_under_planned_gross_daily_sum_cumulative] = dcm_row_raw.over_under_planned_gross_daily_sum_cumulative
      # dcm_row[:planned_cost_reached_daily_sum_cumulative] = dcm_row_raw.planned_cost_reached_daily_sum_cumulative
      # dcm_row[:exact_day_of_cost_reached_daily_sum_cumulative] = dcm_row_raw.exact_day_of_cost_reached_daily_sum_cumulative
      # dcm_row[:capped_cost_to_client_gross_per_line] = dcm_row_raw.capped_cost_to_client_gross_per_line
      dcm_row[:bonus_value_gross_per_line] = dcm_row_raw.bonus_value_gross_per_line
      dcm_row[:ctr] = calculate_ctr(dcm_row[:clicks], dcm_row[:impressions])
      dcm_row[:cvr] = calculate_cvr(dcm_row[:clicks], dcm_row[:total_conversions])

      dcm_rows_data << dcm_row
    end
    dcm_rows_data
  end
  
  ## Below methods are for IO PDF

  def get_io_number (initial = "GER")
   "#{initial}-#{start_date.year.to_s}-#{campaign_number}"
  end

  def get_plan_ref
    "#{client_agency.try(:title)} - #{client.try(:name)} - #{title} / #{mmp_versions.last.try(:version_number)}"
  end

  def check_profile(assignee)
    if assignee && !assignee.profile.nil?
      "#{assignee.profile.first_name} #{assignee.profile.last_name}"
    else
      ""
    end
  end

  def get_account_team
    hsh = {}
    hsh = {
      manager_title: second_assignee.nil? ? "" : second_assignee.profile.title,
      manager_name: check_profile(second_assignee), 
      manager_email: second_assignee.nil? ? '' : second_assignee.email, 
      manager_phone: second_assignee.nil? ? '' : second_assignee.profile.phone_number, 
      coordinator_name: check_profile(first_assignee), 
      coordinator_title: first_assignee.nil? ? "" : first_assignee.profile.title,
      coordinator_email: first_assignee.nil? ? '' : first_assignee.email, 
      coordinator_phone: first_assignee.nil? ? '' : first_assignee.profile.phone_number
    }
    
  end

  def get_agency_contact
    hsh = {}
    if client_agency.title != "Direct"
      hsh = {
        name: "#{first_contact.try(:first_name)} #{first_contact.try(:last_name)}", 
        email: "#{first_contact.try(:email)}", 
        phone: "#{first_contact.try(:phone)}", 
        address: "#{first_contact.try(:address)}"
      }
    else
      hsh = {
        name: "#{second_contact.try(:name)} #{second_contact.try(:last_name)}", 
        email: "#{second_contact.try(:email)}", 
        phone: "#{second_contact.try(:contact)}", 
        address: "#{second_contact.try(:address)}"
      }
    end
    
  end

  def get_agency_bill_contact
    hsh = {}
    if client_agency.title != "Direct"
      hsh = {
        bill_to: "#{client_agency.try(:title)}", 
        bill_period: "", 
        contact_person: "#{client_agency.try(:primary_contact_person)}",
        email: "#{client_agency.try(:email)}",
        phone: "#{client_agency.try(:phone)}", 
        address: "#{client_agency.try(:address)}"
      }
    else
      hsh = {
        bill_to: "#{client.try(:name)}", 
        bill_period: "", 
        contact_person: "#{client.try(:first_name)}",
        email: "#{client_agency.try(:email)}",
        phone: "#{client_agency.try(:client_contact)}", 
        address: "#{client_agency.try(:address)}"
      }
    end
    
  end

  def get_general_terms
    "Billing counts based on:      Fixed Cost

     Payment Terms:                  Net 45

     Cancellation: we will endeavour to cancel any bookings if requested to do so. However, should that give rise to cancellation fees or other penalties, these will be onbilled to the Client at net cost.

     This IO is governed by the Geronimo Mobile standard T&Cs as per url                   <a href='http://www.iab.net/media/file/IAB_4As-tsandcs-FINAL.pdf'>http://www.iab.net/media/file/IAB_4As-tsandcs-FINAL.pdf</a>"
  end

  def get_additional_terms
    "Geronimo strives to set the campaigns live as per bookings but due to working hours we are unable to guarantee that campaigns will be able to launch on Saturday or Sunday. We therefore advise that unless necessary all campaigns be scheduled to launch during the standard working week.

     Campaigns will not go live unless a valid PO number and signature are provided"
  end

  def set_campaign_number
    last_campaign_number = Campaign.order("id DESC").first.try(:campaign_number) || 1000
    self.campaign_number = last_campaign_number + 1
  end

  def clone_mmp(old_campaign)
    old_campaign.master_media_publishers.order("created_at ASC").each do |master_media_publisher|
      master_media_publisher.create_nested_models(self)
      MmpPublisher.where(campaign_id: self.id, publisher_id: master_media_publisher.publisher_id).first_or_create
    end
  end

  def calculate_due_date(type, obj, date)
    if type=="ACCREC"
      due_date  = ''
      case obj.type 
      when 'DAYSAFTERBILLDATE' 
        due_date = date + obj.day.to_i
      when 'OFFOLLOWINGMONTH' 
        due_date = date.end_of_month + obj.day.to_i
      when 'DAYSAFTERBILLMONTH' 
        due_date = date.end_of_month + obj.day.to_i
      when 'OFCURRENTMONTH'
        due_date = date.beginning_of_month - 1 + obj.day.to_i
      else
        due_date = date 
      end
    else 
      case obj.type 
      when 'DAYSAFTERBILLDATE' 
        due_date = date + obj.day.to_i
      when 'OFFOLLOWINGMONTH' 
        due_date = date.end_of_month + obj.day.to_i
      when 'DAYSAFTERBILLMONTH' 
        due_date = date.end_of_month + obj.day.to_i
      when 'OFCURRENTMONTH'
        due_date = date.beginning_of_month - 1 + obj.day.to_i
      else
        due_date = date 
      end
    end 
    return due_date.to_date 
  end

  #---- end of instance methods------------------

  private
  # validate date ranges
  # def campaign_dates_valid?
  #   if start_date && start_date > end_date
  #     errors.add(:dates, "end date must be greater than start date")
  #   end
  # end



  def set_unique_key
    self.camp_id = ("CA#{Time.now.to_i}" + "#{Array.new(4) { rand(1...9) }.join().to_i}")
  end

  # create notification based on the user action on campaign
  def create_notification
    [first_assignee_id, second_assignee_id].each do |as_user_id|
      if as_user_id
        message = if transaction_include_any_action?([:create])
          "New Campaign '#{self.title}' is created"
        else
          "'#{self.title}' has been updated"
        end
      end
      self.notifications.create(user_id: as_user_id, message: message, title: self.class.name, extra_info: {campaign_id: self.id}.to_json)
    end
    message = if transaction_include_any_action?([:create])
      "New Campaign '#{self.title}' is created"
    else
      "'#{self.title}' has been updated"
    end
    self.notifications.create(user_id: nil, message: message, title: self.class.name, extra_info: {campaign_id: self.id})
  end

  def set_status
    set_ca_states("D", "RB")
    return if self.status.present?
    self.update_column(:status_id, Status.get_new_status_id)
  end



end
