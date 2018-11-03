module V1
  class CampaignsController < ApplicationController
    include ActionView::Helpers::NumberHelper
    # TODO should changes this to except
    before_action :set_campaign, only: [:show, :update, :destroy, :add_attachments, :sent_proposal,
                    :download_briefing, :remove_attachment, :send_rfp, :uploade_client_proposals,
                    :get_proposal_email_template, :update_status, :rfp_sent_to_publishers,
                    :upload_mmp_documents, :mmp_documents, :generate_insertion_order,
                    :all_campaign_assets, :all_activities, :add_mockups,:add_tags,:get_tags_view, :mockups, :add_creative_assets, :creative_assets, :mockup_mail, :creative_assets_mail,
                    :add_screenshots, :get_screen_shots, :add_site_list ,:get_site_list, :get_background_info, :add_background_info,
                    :get_list_specification, :destroy_list_specification, :approve_assets, :rejected_assets,:destroy_ca_target_audiences,
                    :update_mmc_notes, :update_publisher_response_note,  :send_comman_template_mails, :send_comman_mails,:get_sizmek_raws_data, :create_recommdation, :get_recommdations, :destroy_recommdation,
                    :campaign_reports, :create_important_detail_chat, :get_important_detail_chat,:campaign_invoice, :create_campaign_invoice_data,:get_campaign_invoice_data,
                    :export_mmps_records, :export_trafficking_records, :import_mmps_records, :import_dcm_records, :send_report_to_client,
                    :import_sizmek_raws, :all_dcm_records,:delete_ta_campaign, :import_publisher_rows, :all_publisher_rows, :send_media_plan_to_client, :update_campaign_progress_status,
                    :update_trafficking_records, :calculate_publisher_rows, :calculate_sizemek_rows, :calculate_dcm_rows, :create_campaign_combined_report, :get_campaign_combined_report, :get_io_table_calculation, :get_dcm_rows_data]

    # GET /campaigns
    def index
      @campaigns = Campaign.includes(:client_agency, :client, :status, :ads_server, :campaign_status, :ca_budget, :ca_sub_stage, :next_step, :ca_budget_phases, :ta_campaigns, :publisher_vendors, :first_contact, :second_contact, first_assignee: [:profile, :role], second_assignee: [:profile, :role] , created_by_user: [:profile, :role], updated_by_user: [:profile, :role], ca_target_audiences: [:target_audience]).order("id DESC") 
      render json: @campaigns, each_serializer: V1::CampaignSerializer, root: "campaigns", adapter: :json
      #render json: @campaigns
    end

    def without_current_user_campaign
      ids = current_user.teammate_campaign_todos.pluck(:campaign_id)
      @campaigns = Campaign
                   .includes(:client_agency, :client, :status, :ads_server, :campaign_status, :ca_budget, :ca_sub_stage, :next_step, :ca_budget_phases, :ta_campaigns, :publisher_vendors, :first_contact, :second_contact, first_assignee: [:profile, :role], second_assignee: [:profile, :role] , created_by_user: [:profile, :role], updated_by_user: [:profile, :role], ca_target_audiences: [:target_audience])
                   .where.not(first_assignee_id: current_user)
                   .where.not(id: ids)
                   .order("id DESC")
      render json: @campaigns, each_serializer: V1::CampaignSerializer, root: "campaigns", adapter: :json
      #render json: @campaigns
    end

    def campaign_lists
      @campaigns = []
      Campaign.includes(:master_media_publishers).all.order("id DESC").each do |campaign| 
         if campaign.master_media_publishers.count > 0
          @campaigns  << campaign
         end
      end
      render json: @campaigns, each_serializer: V1::CampaignListsSerializer, root: "campaigns", adapter: :json
    end

    # GET /campaigns/1
    def show
      #render json: ActiveModelSerializers::SerializableResource.new(Campaign.first, {})
      render json: @campaign, serializer: V1::CampaignSerializer, root: "campaign", adapter: :json
    end

    def all_campaign_assets
      render json: {"assets": ActiveModel::Serializer::CollectionSerializer.new(@campaign.all_campaign_assets, serializer: V1::CaAssetSerializer)}
    end

    # POST /campaigns
    def create
      @campaign = Campaign.new(campaign_params)
      if @campaign.save!
        begin
          new_data = ActiveModelSerializers::SerializableResource.new(@campaign, serializer: V1::CampaignSerializer).as_json
          description = "New Campaign Created by #{@user.first_name}"
          @campaign.log_details(@user.id, 'create', description, @campaign, new_data, nil)
        rescue Exception => e
          puts e
        end
        if GeneralSetting.email_for_campaign_creation?
          UserMailer.campaign_email(@campaign, "New Campaign #{@campaign.title} Created", action_name).deliver_now
        end
        #@campaign = @campaign.save_attachments(params)
        render json: @campaign, serializer: V1::CampaignSerializer, root: "campaign", status: :created, location: v1_campaign_path(@campaign), adapter: :json
      else
        render json: @campaign.error_messages, status: :unprocessable_entity
      end
    end

    #add multiple attachement of any type
    def add_attachments
      status, message, records = @campaign.save_attachments(params, @user.id)
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded Client Proposal", ca_asset, ca_assets, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end

    #add multiple attachement of any type
    def add_mockups
      status, message, records = @campaign.save_attachments(params, @user.id, "mockups")
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded mockups", ca_asset, ca_assets, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end

    def mockups
      render json: {"mockups": ActiveModel::Serializer::CollectionSerializer.new(@campaign.mockups, serializer: V1::CaAssetSerializer)}
    end

    # add multiple file for back group info
    def add_background_info
      status, message, records = @campaign.save_attachments(params, @user.id, "background_info")
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded Background Info", ca_asset, ca_assets, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
        
      else
        render json: {message: message}, status: status_code
      end
    end

    def get_background_info
      render json: {"ca_background_info_assets": ActiveModel::Serializer::CollectionSerializer.new(@campaign.background_info, serializer: V1::CaAssetSerializer)}
    end

    def creative_assets
      render json: {"creative_assets": ActiveModel::Serializer::CollectionSerializer.new(@campaign.creative_assets, serializer: V1::CaAssetSerializer)}
    end

    #add multiple attachement of any type
    def add_creative_assets
      status, message, records = @campaign.save_attachments(params, @user.id, "creative_assets")
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded creative assets", ca_asset, ca_assets, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end


    #add tag of any type
    def add_tags
      status, message, records = @campaign.save_attachments(params, @user.id, "add_tags")
      if status
        begin
          records.each do |add_tag|
            add_tags = ActiveModelSerializers::SerializableResource.new(add_tag, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded add tags", add_tag, add_tags, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end


    # get add tags details
    def get_tags_view
      render json: {"get_tag_view": ActiveModel::Serializer::CollectionSerializer.new(@campaign.campaign_add_tags, serializer: V1::CaAssetSerializer)}
    end


     #add tag of any type
    def add_screenshots
      status, message, records = @campaign.save_attachments(params, @user.id, "screen_shots")
      if status
        begin
          records.each do |screen_shot|
            screen_shots = ActiveModelSerializers::SerializableResource.new(screen_shot, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded add screen shots", screen_shot, screen_shots, nil)
          end
          status_code = :ok
          render json: {}, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end


    def add_specification
      #add_spec = AddSpec.where(campaign_id: params[:id], publisher_id: params[:add_spec][:publisher_id]).first
      add_spec = AddSpec.new(addspec_params) #if add_spec.blank?
      add_spec.campaign_id = params[:id]
      if add_spec.save
        status, message, records = add_spec.save_attachments(params, @user.id, "add_specification")
        render json: {message: "Record successfully inserted"}, adapter: :json, status: 200
      else
        render json: add_spec.error_messages, add_spec: :unprocessable_entity
      end
    end

    def get_list_specification
      add_specs = @campaign.add_specs
      render json: {"add_specs": ActiveModel::Serializer::CollectionSerializer.new(add_specs, serializer: V1::AddSpecSerializer)}
    end

    def destroy_list_specification
      add_spec =  @campaign.add_specs.where("id = ?", params[:add_spec_id]).first
      if add_spec
        add_spec.destroy
      else
         render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end


    # get add tags details
    def get_screen_shots
      render json: {"screen_shot": ActiveModel::Serializer::CollectionSerializer.new(@campaign.get_screen_shot, serializer: V1::CaAssetSerializer)}
    end


    def add_site_list
      begin
        site_params.each do |site_list|
          site_list_object = CampaignImportantDetail.where(id: site_list[:id]).first if site_list[:id].present?
          if site_list_object.present?
            if site_list['_destroy'].present?
              site_list_object.destroy!
            else
              site_list.delete('_destroy')
              site_list_object.update_attributes(site_list)
            end
          else
            site_list.delete('_destroy')
            unless site_list[:url].blank?
              site_list_object = CampaignImportantDetail.new(site_list)
              site_list_object.campaign_id = @campaign.id
              site_list_object.save
            end
          end
        end
        render json: {message: "success"}, status: 200
      rescue Exception => e
        render json: {error: e}, site_list: :unprocessable_entity
      end

    end


    def get_site_list
      render json: {"site_list": @campaign.campaign_important_details.active_url}
    end

    # Remove a attachement of related camapign
    def remove_attachment
      ca_asset = @campaign.ca_assets.where(id: params[:ca_asset_id]).first
      if ca_asset
        if ca_asset.destroy
          head :no_content
        else
          render json: ca_asset.error_messages, status: :unprocessable_entity
        end
      else
        render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end

    #import campaigns through csv
    def import
      campaign_import = CampaignImport.new(params[:attachment])
      status, message = campaign_import.import
      if status
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end

    end

    def send_rfp
      rfp = @campaign.ca_rfps.where(publisher_id: params[:publisher_id]).last
      if rfp
        rfp.send_rfp
      else
        if params[:agency_id].blank?
          publisher_ids = [params[:publisher_id]]
        else
          publisher_ids = Agency.find(params[:agency_id]).publishers.map(&:id)
        end
        CaRfp.create_and_send_rfp(@campaign.id, publisher_ids)
      end
      render json: {message: "email send successfully"}, status: :ok
    end

    def update_status
      if @campaign.update_attributes(status_id: params[:status_id])
        if GeneralSetting.email_for_campaign_cancellation?
          UserMailer.campaign_email(@campaign, "campaign has been cancelled", action_name).deliver_now if @campaign.is_cancelled?
        end
        render json: @campaign, serializer: V1::CampaignSerializer, root: "campaign", adapter: :json
      else
        render json: {message: @campaign.error_messages}, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /campaigns/1
    def update
      changed = {}
      old_data = ActiveModelSerializers::SerializableResource.new(@campaign, serializer: V1::CampaignSerializer).to_json
      if @campaign.update(campaign_params)
        begin
          new_data = ActiveModelSerializers::SerializableResource.new(@campaign, serializer: V1::CampaignSerializer).to_json
          description = "Campaign updated by #{@user.first_name}"
          old_data_json = JSON.parse(old_data)
          new_data_json = JSON.parse(new_data)
          all_keys = old_data_json.keys
          all_keys.each do |key|
            if new_data_json[key] != old_data_json[key]
              changed[key] = [new_data_json[key], old_data_json[key]]
            end
          end
          @campaign.log_details(@user.id, 'update', description, @campaign, new_data, old_data, {changed: changed.to_json})
         rescue Exception => e
           puts e
         end
        if GeneralSetting.email_for_campaign_updation?
          UserMailer.campaign_email(@campaign, "campaign #{@campaign.title} Updated", action_name).deliver_now
        end
        render json: @campaign, serializer: V1::CampaignSerializer, root: "campaign", adapter: :json
      else
        render json: @campaign.error_messages, status: :unprocessable_entity
      end
    end

    def uploade_client_proposals
      client_proposal = @campaign.first_or_create_client_proposal
      status, error, records = client_proposal.upload_documents(params)
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id, 'create', "Uploaded Client Proposal", ca_asset, ca_assets, nil)
          end
        rescue Exception => e
          puts e
        end
        render json: {message: "success"}, status: :ok
      else
        render json: {message: "success"}, status: :unprocessable_entity
      end
    end

    def sent_proposal
      client_proposal = @campaign.first_or_create_client_proposal
      status, message = client_proposal.send_proposal(params)
      if status
        begin
          @campaign.log_details(@user.id, 'update', "Proposal sent to client", client_proposal, nil, nil)
        rescue Exception => e
          puts e
        end
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end

    def get_proposal_email_template
      email_template = EmailTemplate.where(code: "CPS").first
      if email_template
        tm = TextModifier.new(email_template)
        email_template = tm.proposal_modifier(@campaign)
      render json: {email_template: email_template}, status: :ok
      else
        render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end

    def download_briefing
      status, ca_asset_or_message = @campaign.generate_rfp_pdf
      if status
        render json: {url: BASEURL+ca_asset_or_message.asset_path.url}, status: :ok
      else
        render json: {message: ca_asset_or_message}, status: :unprocessable_entity
      end
    end

    def rfp_sent_to_publishers
      render json: {publishers: @campaign.sent_rpfs}
      #render json: {"rfp_sents": ActiveModel::Serializer::CollectionSerializer.new(@campaign.ca_rfps.email_sent, serializer: V1::CaRfpSerializer)}
    end

    def upload_mmp_documents
      status, message, records = @campaign.upload_mmp_documents(params, @user.id)
      if status
        records.each do |ca_asset|
          ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
          @campaign.log_details(@user.id, 'create', "Uploaded master media plan documents", ca_asset, ca_assets, nil)
        end
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end

    def mmp_documents
      render json: {"mmp_documents": ActiveModel::Serializer::CollectionSerializer.new(@campaign.mmps_documents, serializer: V1::CaAssetSerializer)}
    end


    # DELETE /campaigns/1
    def destroy
      @campaign.destroy
    end

    def destroy_ca_target_audiences
       @campaign.ca_target_audiences.where("group_id = ?", params[:group_id]).delete_all
    end

    def destroy_ca_assets
      ca_asset = CaAsset.where("id = ?", params[:ca_asset_id]).first
      if ca_asset
        ca_asset.destroy
      else
        render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end


    def update_mmc_notes
      if @campaign
        @campaign.update(notes: params[:notes])
        render json: {message: "Notes Successfully updated!"}, status: :ok
      else
        render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end


    def update_publisher_response_note
      if @campaign
        @campaign.update(update_publisher_response_note: params[:publisher_response_note])
        render json: {message: "Publisher Response Note Successfully updated!"}, status: :ok
      else
        render json: {message: "No record found"}, status: :unprocessable_entity
      end
    end


    def generate_insertion_order
      status, message = @campaign.generate_insertion_order(params.merge({current_user_id: @user.id}))
      if status
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end

    # will return all activities related to campaign
    def all_activities
      render json: {"activities": ActiveModel::Serializer::CollectionSerializer.new(@campaign.campaign_activities, serializer: V1::CampaignActivitySerializer)}
    end

    # def log_details(action, description, objectable, new_data, old_data, extra={})
    #   @campaign.campaign_activities.create!(action: action,
    #                                 description: description,
    #                                 objectable_id: objectable.id,
    #                                 objectable_type: objectable.class.name,
    #                                 old_data: old_data,
    #                                 new_data: new_data,
    #                                 user_id: @user.id)
    # end

    def send_comman_template_mails
      if params[:receiver_type] == "client"
        @client = Client.where("id = ? ", params[:receiver_id]).first
      else
        @publisher = Publisher.where("id = ?", params[:receiver_id]).first
      end
      if params[:template_type] == "site_list"
        template_attachment_url = @campaign.campaign_important_details.where("id IN (?)", params[:value_ids])
        @site_list_url = template_attachment_url.map(&:url) if template_attachment_url
      else
        template_attachment_url = @campaign.ca_assets.where("id IN (?)", params[:value_ids])
        @attachments =  ActiveModel::Serializer::CollectionSerializer.new(template_attachment_url, serializer: V1::CaAssetSerializer) if template_attachment_url
      end
      @email_template = EmailTemplate.where("code = ? ",params[:template_type]).first
      if @email_template
       tm = TextModifier.new(@email_template)
       name = @client.present? ? @client.try(:name) : @publisher.name

        @email_template = tm.template_modifier(@campaign,name)
      end
      email_templates ={template: @email_template, email_to: @client.present? ? @client.try(:email) : @publisher.try(:primary_email)}

      render json: {email_templates: email_templates, attachments: @attachments, site_list_url: @site_list_url, template_type: params[:template_type] }, status: :ok
    end


    def send_comman_mails
      begin
        UserMailer.send_template_mail(params, @campaign).deliver_now
        render json: {message: "Email send successfully"}, status: :ok
      rescue Exception => e
        render json: {message: "Email Failed!"}, status: :ok
      end
    end

    def mockup_mail
      UserMailer.send_mockup_mail(@campaign).deliver_now
      @campaign.update_column(:mockup_sent_at, DateTime.now)
      render json: {message: "Email send successfully"}, status: :ok
    end

    def creative_assets_mail
      UserMailer.send_creative_assets_mail(@campaign).deliver_now
      @campaign.update_column(:ca_sent_at, DateTime.now)
      render json: {message: "Email send successfully"}, status: :ok
    end

    def approve_assets
      @campaign.ca_assets.where(id: params[:ca_asset_ids]).update_all(approved: true)
      render json: {message: "Records update successfully", status: true}, status: :ok
    end

    def rejected_assets
      @campaign.ca_assets.where(id: params[:ca_asset_ids]).update_all(approved: false)
      render json: {message: "Records update successfully", status: true}, status: :ok
    end

    def list_kpi_items
      @kpi_items = KpiItem.all
      render json: {kpi_items: @kpi_items}
    end


    # import sizmek raws record from csv file
    def import_sizmek_raws
      status, message = false, "something went wrong"
      ActiveRecord::Base.transaction do
        SizmekRaw.where(campaign_id: @campaign.id).destroy_all
        sizmek_raw = SizmekRawImport.new(@campaign.id, params[:attachment])
        status, message = sizmek_raw.import
        SizmekRaw.calculate_results(@campaign.id)
        #ReportWorker.perform_async(@campaign.id)
      end
      
      if status
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end

    def all_dcm_records
      if params[:start_date] && params[:end_date]
        dcm_rows = @campaign.dcm_rows.where(placement_date: (params[:start_date].to_date..params[:end_date].to_date))
                    .order('placement_date asc')#.group_by {|a|a.placement_date}
      else
        dcm_rows = @campaign.dcm_rows.order('placement_date asc')#.group_by {|a|a.placement_date}
      end
      render json: {dcm_rows: dcm_rows}, status: :ok
    end


    def all_publisher_rows
      
      arrange_publisher_row = @campaign.arrange_publisher(params)
      #imported_data = @campaign.publisher_rows
      publisher_package_data = @campaign.publisher_package_data
      #render json: {publisher_rows: arrange_publisher_row, imported_data: imported_data, package_data: publisher_package_data}, status: :ok
      render json: {publisher_rows: arrange_publisher_row, package_data: publisher_package_data}, status: :ok

    end


     # import sizmek raws record from csv file
    def import_publisher_rows
      publisher_row = PublisherRowImport.new(@campaign.id, params[:attachment])
      status, message = publisher_row.import
      PublisherRow.calculate_results(@campaign.id)
      if status
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end


    # import sizmek raws record from csv file
    def import_dcm_records
      dcm_row = DcmImport.new(@campaign.id, params[:attachment])
      status, message = dcm_row.import
      if status
        render json: {message: message}, status: :ok
      else
        render json: {message: message}, status: :unprocessable_entity
      end
    end


    def get_sizmek_raws_data
      @sizmek_package_data = @campaign.grouped_with_packaged
      @sizmek_raws = @campaign.get_sizmek_raws(params)
      # render json: {sizmek_raws: @sizmek_raws, imported_data: @campaign.sizmek_raws, package_data: @sizmek_package_data}
      render json: {sizmek_raws: @sizmek_raws, package_data: @sizmek_package_data}
    end

    # create new Recommdation for Campaign and related publiser
    def create_recommdation
      @recommdation = Recommdation.new(recommdation_params)
      @recommdation.campaign_id = @campaign.id
      if @recommdation.save
        render json: @recommdation, status: :ok
      else
        render json: @recommdation.error_messages, status: :unprocessable_entity
      end
    end


    def get_recommdations
      @recommdations = @campaign.recommdations
      render json: {recommdations: @recommdations}
    end

    def destroy_recommdation
      @recommdation = @campaign.recommdations.where("id = ?", params[:recommdation_id]).first
      if @recommdation.destroy
        head :no_content
      else
        render json: "Record not found", status: :unprocessable_entity
      end
    end

    def create_recommdation_type
      @recommdation_type = RecommdationType.new(recommdation_type_params)
      if @recommdation_type.save
        render json: @recommdation_type, status: :ok
      else
        render json: @recommdation_type.error_messages, status: :unprocessable_entity
      end
    end


    def update_recommdation_type
      @recommdation_type = RecommdationType.where("id = ?", params[:id]).first
      if @recommdation_type
        @recommdation_type.update_attributes(recommdation_type_params)
        render json: @recommdation_type, status: :ok
      else
        render json: @recommdation_type.error_messages, status: :unprocessable_entity
      end
    end

    def get_recommdation_types
      @recommdation_types = RecommdationType.all
      render json: {recommdation_types: @recommdation_types}
    end

    def destroy_recommdation_type
      @recommdation_type = RecommdationType.where("id = ?", params[:id]).first
      if @recommdation_type.destroy
        head :no_content
      else
        render json: "Record not found", status: :unprocessable_entity
      end
    end


    def create_campaign_combined_report
      if @campaign.campaign_combined_report.present? 
        @campaign.campaign_combined_report.update_attributes(campaign_combined_params)
      else
        campaign_combine_report = CampaignCombinedReport.new(campaign_combined_params)
        campaign_combine_report.campaign_id = @campaign.id
        campaign_combine_report.save
      end
       render json:  @campaign.campaign_combined_report, status: :ok
    end

    def get_campaign_combined_report
      campaign_combined_report = @campaign.campaign_combined_report
      render json: {campaign_combined_report: campaign_combined_report || {} }
    end


    def get_recommdation_type
      @recommdation_type = RecommdationType.find(params[:id])
      render json: {recommdation_type: @recommdation_type}
    end


    #show sum of all numeric fields fof sizmek raws group by package name
    def campaign_reports
      sizmek_raws_reports =[]
      @campaign_reports = @campaign.sizmek_raws.group_by(&:package_name)
      @campaign_reports.each do |package_na, campaign_report|
        campaign_sizmek = {}
        campaign_sizmek[:package_name] = campaign_report.map(&:package_name).first
        campaign_sizmek[:sum_unit_cost] = campaign_report.map(&:unit_cost).compact.sum
        campaign_sizmek[:sum_served_impressions] = campaign_report.map(&:served_impressions).compact.sum
        campaign_sizmek[:sum_clicks] = campaign_report.map(&:clicks).compact.sum
        campaign_sizmek[:sum_total_media_cost] = campaign_report.map(&:total_media_cost).compact.sum
        campaign_sizmek[:sum_unit_cost] = campaign_report.map(&:unit_cost).compact.sum
        campaign_sizmek[:sum_post_click_conversions] = campaign_report.map(&:post_click_conversions).compact.sum
        campaign_sizmek[:sum_post_impression_conversions] = campaign_report.map(&:post_impression_conversions).compact.sum
        campaign_sizmek[:sum_total_conversions] = campaign_report.map(&:total_conversions).compact.sum
        sizmek_raws_reports << campaign_sizmek
      end

      if sizmek_raws_reports
        render json: {campaign_reports: sizmek_raws_reports, imported_data: @campaign.sizmek_raws}
      else
        render json: "Record not found", status: :unprocessable_entity
      end
    end


    # create important details chat logs
    def create_important_detail_chat
      @important_detail_chat = ImportantDetailsChatLog.new(important_detail_chat_params)
      @important_detail_chat.campaign_id = @campaign.id
      if @important_detail_chat.save
        render json: @important_detail_chat, status: :ok
      else
        render json: @important_detail_chat.error_messages, status: :unprocessable_entity
      end
    end

    def get_important_detail_chat
      important_detail_chats = @campaign.important_details_chat_logs.where('row_id = ?', params['row_id'])
      render json: {important_detail_chats: ActiveModel::Serializer::CollectionSerializer.new(important_detail_chats, serializer: V1::ImportantDetailsChatLogSerializer)}
    end

    #get
    def campaign_invoice
      campaign_invoice = @campaign.campaign_mmcs
      render json: {campaign_invoice: campaign_invoice}
    end


    def client_invoices
      client_invoices_records =  $client.Invoice.all
      render json:  client_invoices_records
    end

    def create_client_invoice
      
      campaign = Campaign.find(params[:campaign_id]) if params[:campaign_id].present?
      # campaign currency
      currency_code = campaign.currency_code.blank? ? "AUD" : campaign.currency_code
      if params[:type] == "ACCREC"
          if campaign.client_agency.title != "Direct"
            billing_entity = campaign.client_agency.full_trade_name
          else
            billing_entity = campaign.client.full_trade_name
          end
          str = 'Name.Contains' + '("' + billing_entity + '")'

          contact = $client.Contact.all(:where => str, page: 1).first
          if !contact.blank?
            # Xero Default Revenue Code
            revenue_code = contact.sales_default_account_code
            # Invoices Due Date
            due_date = campaign.calculate_due_date("ACCREC",contact.payment_terms.sales, params[:date].to_date)

            # Tax Rate 
            tax_type = contact.tax_number
            # Reference 
            reference = campaign.get_campaign_name_for_invoice
            # IO Number
            io_number =  campaign.get_io_number
            unless $client.TrackingCategory.all.last.options.map(&:name).include?(io_number)
              xero = $client.TrackingCategory.all.last
              option = xero.add_option(name: io_number)
              Xeroizer::Record::OptionModel.set_api_controller_name "TrackingCategories/#{xero.tracking_category_id}/Options"
              option.save
            end

            invoice = $client.Invoice.build(:type => "ACCREC",:contact => contact,
               :date => params[:date].to_date,
               :due_date => due_date,
               :status => params[:status],
               :currency_rate => params[:currency_rate],
               :line_amount_types => params[:line_amount_types],
               :sent_to_contact => params[:sent_to_contact], 
               :currency_code => currency_code,
               :amount_paid => params[:amount_paid],
               :reference => reference,
               :amount_due => params[:amount_due])
                
            params[:line_items].each do |line_item|
              invoice.add_line_item(:description => line_item[:description], 
                                  :line_amount => line_item[:line_amount],
                                  :quantity => line_item[:quantity], 
                                  :discount_rate => line_item[:discount], 
                                  :unit_amount => line_item[:unit_amount], 
                                  :account_code => revenue_code,
                                  :tracking =>  [
                                      { :option => "Geronimo", :name => "Entity" },
                                      { :option => io_number, :name => "IO Number" }
                                  ])
            end
            if invoice.save 
              ## Send attachment to xero
              if campaign
                last_order = campaign.get_last_insertion_order
                ca = last_order.ca_assets.order("created_at ASC").last if last_order
                if ca && ca.title.to_s == "insertion_order_pdf" && File.file?("#{Rails.root}/public/uploads/ca_asset/asset_path/#{ca.id}/#{ca.file_name}")
                  invoice.attach_file(ca.file_name, "#{Rails.root}/public/uploads/ca_asset/asset_path/#{ca.id}/#{ca.file_name}", "application/pdf") 
                end
              end
              render json: invoice, status: :ok
            else
              render json: invoice.errors, status: :unprocessable_entity
            end
          else
            #will to do
            #UserMailer.xero_contact_not_found(billing_entity).deliver_now
            render json: {message: "Contact not found"}, status: :unprocessable_entity
          end
      else
        if campaign.client_agency.title != "Direct"
          billing_entity = campaign.client_agency.full_trade_name
        else
          billing_entity = campaign.client.full_trade_name
        end
        str = 'Name.Contains' + '("' + billing_entity + '")'
        agency_contact = $client.Contact.all(:where => str, page: 1).first

        publisher_billing_entity = Publisher.find(params[:publisher_id]).full_trade_name if params[:publisher_id].present?
        str = 'Name.Contains' + '("' + publisher_billing_entity + '")'
        publisher_contact = $client.Contact.all(:where => str, page: 1).first
        io_number =  campaign.get_io_number
        unless $client.TrackingCategory.all.last.options.map(&:name).include?(io_number)
          xero = $client.TrackingCategory.all.last
          option = xero.add_option(name: io_number)
          Xeroizer::Record::OptionModel.set_api_controller_name "TrackingCategories/#{xero.tracking_category_id}/Options"
          option.save
        end 
        if !agency_contact.blank? && !publisher_contact.blank?
          expanses_code = agency_contact.purchases_default_account_code
          reference = campaign.get_campaign_name_for_publisher_invoice
          due_date = campaign.calculate_due_date("ACCPAY", agency_contact.payment_terms.bills, params[:date].to_date)
          invoice = $client.Invoice.build(:type => "ACCPAY",:contact => publisher_contact,
           :date => params[:date].to_date,
           :due_date => due_date,
           :status => params[:status],
           :currency_rate => params[:currency_rate],
           :line_amount_types => params[:line_amount_types],
           :sent_to_contact => params[:sent_to_contact],
           :currency_code => currency_code,
           :amount_paid => params[:amount_paid],
           :invoice_number => reference,
           :amount_due => params[:amount_due])
          params[:line_items].each do |line_item|
          invoice.add_line_item(:description => line_item[:description], 
                          :line_amount => line_item[:line_amount],
                          :quantity => line_item[:quantity],                                  
                          :unit_amount => line_item[:unit_amount], 
                          :account_code => expanses_code, 
                          :tax_amount=> line_item[:tax_amount],
                          :tracking =>  [
                              { :option => "Geronimo", :name => "Entity" },
                              { :option => io_number, :name => "IO Number" }
                          ])  

          end 
          if invoice.save 
            ## Send attachment to xero
            if campaign
              last_order = campaign.get_last_insertion_order
              ca = last_order.ca_assets.order("created_at ASC").last if last_order
              if ca && ca.title.to_s == "insertion_order_pdf" &&  File.file?("#{Rails.root}/public/uploads/ca_asset/asset_path/#{ca.id}/#{ca.file_name}")
                invoice.attach_file(ca.file_name, "#{Rails.root}/public/uploads/ca_asset/asset_path/#{ca.id}/#{ca.file_name}", "application/pdf") if ca.file_name
              end
            end
            render json: invoice, status: :ok
          else
            render json: invoice.errors, status: :unprocessable_entity
          end
        else
          #will to do
          #UserMailer.xero_contact_not_found(billing_entity).deliver_now
          render json: {message: "Contact not found"}, status: :unprocessable_entity
        end
      end
    end

    # create Campaign Invoice data
    def create_campaign_invoice_data
      @campaign_invoice = @campaign.campaign_invoices.new(campaign_invoice_params)
      if @campaign_invoice.save
        @campaign_invoice.campaign_invoice_pdf
        render json: @campaign_invoice, serializer: V1::CampaignInvoiceSerializer, root: "campaign_invoice", status: :created, adapter: :json
      else
        render json: @campaign_invoice.error_messages, status: :unprocessable_entity
      end
    end


    def get_campaign_invoice_data
      campaign_invoices = @campaign.campaign_invoices
      render  json: {campaign_invoices: ActiveModel::Serializer::CollectionSerializer.new(campaign_invoices, serializer: V1::CampaignInvoiceSerializer)}
    end

    def get_invoice_number
      invoice_number = CampaignInvoice.last.try(:invoice_number)
      if invoice_number.blank?
        invoice_number = "INV-000001"
      else
        invoice_number = invoice_number.split("-").last
        invoice_number = invoice_number.next
      end
      render json: {invoice_number: invoice_number}
    end

    def export_mmps_records
      render json: {path: ImportExportMmp.export_to_csv(@campaign, @user.id)}, status: :ok
    end

    def export_trafficking_records
      render json: {path: ImportExportMmp.export_to_csv(@campaign, @user.id, 'trafficking')}, status: :ok
    end

    def update_trafficking_records
      if params[:upload_file].blank?
        render json: {error: "Please upload file"}, status: :unprocessable_entity
        return
      end

      status, msg = ImportExportMmp.update_trafficking_records(@campaign, params[:upload_file])
      if status
        render json: {path: ImportExportMmp.export_to_csv(@campaign, @user.id, 'trafficking')}, status: :ok
      else
        render json: {error: msg}, status: :unprocessable_entity
      end
    end

    def import_mmps_records
      if params[:upload_file].blank?
        render json: {error: "Please upload file"}, status: :unprocessable_entity
        return
      end

      status, msg = ImportExportMmp.import_from_csv(@campaign, params[:upload_file])
      if status
        @mmp = @campaign.master_media_plans
        render json: {master_media_publishers: @mmp}, status: :ok
      else
        render json: {error: msg}, status: :unprocessable_entity
      end
    end


    # delete ta-cmapigns records 

    def delete_ta_campaign
       @ta_campaign = @campaign.ta_campaigns.where("id = ?", params[:ta_campaign_id]).first
      if @ta_campaign && @ta_campaign.destroy
        head :no_content
      else
        render json: "Record not found", status: :unprocessable_entity
      end
    end

    def get_locations
      locations = []
      if params[:attachment].blank?
        render json: "No File", status: :unprocessable_entity
        return
      end
      csv_text = File.read(params[:attachment].path) rescue nil
      csv = CSV.parse(csv_text, :headers => true)
      csv.each do |row|
        locations << row[0]
      end
      render json: {locations: locations}, status: :ok
    end


    def send_media_plan_to_client
      status, message, records = @campaign.save_attachments(params, @user.id, "media_plan_attachments")
      params[:user_id] = @user.id
      if status
        begin
          records.each do |ca_asset|
            ca_assets = ActiveModelSerializers::SerializableResource.new(ca_asset, serializer: V1::CaAssetSerializer).to_json
            @campaign.log_details(@user.id,'create', "Uploaded Media Plan Attachment", ca_asset, ca_assets, nil)
          end 
          UserMailer.send_media_plan_mail(params, @campaign).deliver_now
          status_code = :ok
          render json: { }, status: status_code
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
        render json: {message: message}, status: status_code
      end
    end

    def send_report_to_client
      client = Client.where(email: client_send_io_params["campaign_data"]["email_data"]["email_to"]).first
      status, message = @campaign.generate_final_client_insertion_order(client_send_io_params["campaign_data"]["combine_data"], client)  
      if  status
        begin
          UserMailer.send_client_insertion_report_mail(client_send_io_params["campaign_data"]["email_data"], @campaign, client).deliver_now
          status_code = :ok
          render json: { }, status: status_code 
        rescue Exception => e
          message, status_code = e, :unprocessable_entity
          render json: {message: message}, status: status_code
        end
      else
      end 
    end

    def update_campaign_progress_status
      status, message = @campaign.update_campaign_progress_status(params[:current_status])
      if status
        status_code = :ok
        render json: @campaign, serializer: V1::CampaignSerializer, root: "campaign",  status: status_code, adapter: :json and return
        #render json: {error: message, campaign: @campaign}, status: status_code
      else
        status_code = :unprocessable_entity
        render json: {error: message}, status: status_code and return
      end
      
    end


    #TEMMM METHODS_=====================================================


    #temp methods should remove after shceduler installed properly
    def calculate_publisher_rows
      PublisherRow.calculate_results(@campaign.id)
      render json: {status: :ok}
    end

    def calculate_sizemek_rows
      SizmekRaw.calculate_results(@campaign.id)
      render json: {status: :ok}
    end


    def calculate_dcm_rows
      DcmRow.calculate_results(@campaign.id)
      render json: {status: :ok}
    end


    def get_dcm_rows_data
      @dcm_row_package_data = @campaign.grouped_with_package_name_dcm
      @dcm_rows = @campaign.get_dcm_rows(params)
      DcmRow.calculate_results(@campaign.id)
      #render json: {dcm_rows: @dcm_rows, imported_data: @campaign.dcm_rows, package_data: @dcm_row_package_data}
      render json: {dcm_rows: @dcm_rows, package_data: @dcm_row_package_data}
    end


    def get_io_table_calculation
      io_calculation, total = [], []
      mm_pub_spend, com_percent, bought_net = 0, 0, 0
      marked_publishers = @campaign.marked_publishers
      if marked_publishers.present? 
        marked_publishers.group_by{|a|a.publisher_id}.each do |pub_id, records|
          mm_pub_spend = records.map{|pub|pub.mm_pub_spend.g_sold}.sum  #previously g_bought was used
          com_percent = records.map{|pub|pub.mm_pub_spend.com_value}.sum  #previously com_percent was used
          bought_net = records.map{|pub|pub.mm_pub_spend.sold_net}.sum 
          publisher_data = {}
          publisher_data[:publisher_name] = records.first.publisher.name
          publisher_data[:mm_pub_spend] = "$#{number_with_delimiter(number_with_precision(mm_pub_spend, precision: 2), :delimiter => ',')}"
          publisher_data[:com_percent] = "$#{number_with_delimiter(number_with_precision(com_percent, precision: 2), :delimiter => ',')}"
          publisher_data[:bought_net] = "$#{number_with_delimiter(number_with_precision(bought_net, precision: 2), :delimiter => ',')}"
          publisher_data[:gst] = "$#{ number_with_delimiter(number_with_precision(bought_net * 0.1, precision: 2), :delimiter => ',')}"
          publisher_data[:media_cost] = "$#{number_with_delimiter(number_with_precision(bought_net + (bought_net * 0.1), precision: 2), :delimiter => ',')}"
          io_calculation << publisher_data
        end 
         grand_total = {} 
         grand_total[:mm_pub_spend_total] = "$#{number_with_delimiter(number_with_precision(marked_publishers.map{|a| a.mm_pub_spend.g_sold}.sum, precision: 2), :delimiter => ',')}"
         grand_total[:com_percent_total] = "$#{number_with_delimiter(number_with_precision(marked_publishers.map{|a| a.mm_pub_spend.com_value}.sum, precision: 2) , :delimiter => ',')}"
         grand_total[:sold_net_total] = "$#{number_with_delimiter(number_with_precision(marked_publishers.map{|a| a.mm_pub_spend.sold_net}.sum, precision: 2) , :delimiter => ',')}"
         grand_total[:gst] = "$#{number_with_delimiter(number_with_precision(marked_publishers.map{|a| a.mm_pub_spend.sold_net * 0.1}.sum, precision: 2) , :delimiter => ',')}"
         grand_total[:media_cost_total] = "$#{number_with_delimiter(number_with_precision(marked_publishers.map{|a| a.mm_pub_spend.sold_net + (a.mm_pub_spend.sold_net * 0.1)}.sum, precision: 2), :delimiter => ',')}"
         total << grand_total
       render json: {io_table_calculation: io_calculation, grand_total: total}, status: :ok
      else
        render json: {io_table_calculation: []}
      end 
    end

    def ca_sub_stage
       @ca_sub_stage = CaSubStage.all
       render json: @ca_sub_stage
    end

    def export_campaigns
      @campaigns = Campaign.all.order("id DESC") 
      render json: {path: ExportCampaign.export_to_csv(@user.id, @campaigns, params[:type])}, status: :ok
    end

    #TEMP METHODS========================================================


    private
      # Use callbacks to share common setup or constraints between actions.
      def set_campaign
        @campaign = Campaign.find(params[:id])
      end

      def attachement_params
        params.permit(:attachments => [])
      end

      def campaign_combined_params
         params.require(:campaign_combined_report).permit(:id, :campaign_id,  :results, :insights, :recommdations)
      end


      def site_params
        params.permit(site_list:[:id, :is_checked, :url, :comment, :camapign_id,:_destroy])[:site_list]
      end

      def recommdation_params
        params.require(:recommdation).permit(:id, :publisher_id,  :comment, :camapign_id, :recommdation_type_id)
      end

      def important_detail_chat_params
        params.require(:important_detail_chat).permit(:id, :name, :email, :comment, :camapign_id, :row_id, :post_date,:user_id)
      end

      def recommdation_type_params
        params.require(:recommdation_type).permit(:id, :name)
      end

      def addspec_params
        params.permit(:publisher_id, :placement, :responsive, :animation, :required_assets, :accepted_file_type, :sound, :video, :turnaround_time, :duration , :character_limit, :additional_specs)
      end

      def campaign_invoice_params
        params.require(:campaign_invoice).permit(:campaign_id, :invoice_header, :invoice_footer, :invoice_company_address, :invoice_terms_and_conditions,
          :invoice_thankyou_message, :date, :invoice_to, :ship_to, :due_date, :terms, :invoice_number,
          {invoice_data_attributes: [:id, :campaign_invoice_id, :site_or_product, :description, :discount, :g_sold_to_client]})
      end

      def client_send_io_params
        params.permit(campaign_data: {})
      end

      

      # Only allow a trusted parameter "white list" through.
      def campaign_params
        if action_name == 'create'
          user_params = {created_by: @user.id, updated_by: nil}
        else
          user_params = {updated_by: @user.id}
        end
       #debugger
        params[:campaign][:ca_target_audiences] = params[:campaign][:ca_target_audiences].flatten if params[:campaign].present? && params[:campaign][:ca_target_audiences].present?
        cparams = params.require(:campaign).permit(:title, :city, :start_date, :end_date, :objective, :objective2, :objective3, :budget, :kpi, :kpi2, :kpi3,
                    :primary_kpi_text, :secondary_kpi_text, :tertiary_kpi_text, :campaign_status_id, :client_agency_id, :client_id, :status_id, :ads_server_id, :first_contact_id, :second_contact_id,
                    :first_assignee_id, :second_assignee_id, :priority, :additional_notes, :creative_considrations,
                    :target_audience_others, :version, :is_ms_absorbed_by_media, :mobile_solution_budget_uploaded,
                    :mobile_solution_budget, :is_mobile_solution, :is_budget_net, :budget, :objective_ratio, :currency_code,
                    :scheduler_number, :job_number, :background_information, :created_by, :updated_by, :extra_info, :urls, :exchange_rate,
                    :timezone, :rate_type, :frequency_cap, :frequency_option, :pacing, :pacing_option, :absorb_the_production_into_the_media,
                    :campaign_number,
                    {ca_budget_phases: [:id, :title, :start_date, :end_date, :budget, :percent, :_destroy]},
                    {ta_campaigns: [:id, :age, :gender, :relationship_status, :income, :location, :other_text] },
                    #{ca_target_audiences: [:id, :target_audience_id, :group_id, :_destroy]},
                    ca_budget: [:id, :gross_total_budget, :gross_media_budget, :gross_mobile_solution_budget, :net_total_budget,
                                  :net_media_budget, :net_mobile_solution_budget, :sov_percent_total_budget,
                                  :sov_percent_media, :sov_percent_mobile_solution, :sov_percent_media,
                                  :total_ratio, :media_ratio, :mobile_ratio, :_destroy],
                    ).merge(user_params)
        cparams[:ca_budget_phases_attributes] = cparams.delete :ca_budget_phases if cparams[:ca_budget_phases]
        cparams[:ca_budget_attributes] = cparams.delete :ca_budget if cparams[:ca_budget]
        cparams[:ta_campaigns_attributes] = cparams.delete :ta_campaigns if cparams[:ta_campaigns]
        #cparams[:ca_target_audiences_attributes] = cparams.delete :ca_target_audiences if cparams[:ca_target_audiences]
        cparams.permit!
      end
  end
end
