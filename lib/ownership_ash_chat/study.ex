defmodule OwnershipAshChat.Study do
  use Ash.Domain,
    otp_app: :ownership_ash_chat

  resources do
    resource OwnershipAshChat.Study.Session do
      define :create_session, action: :create
      define :start_session, action: :start
      define :get_session, action: :read, get_by: [:id]
      define :complete_session, action: :complete
      define :export_session, action: :export, get_by: [:id]
      define :export_session_by_case_id, action: :export, get_by: [:case_id]
      define :export_session_by_case_number, action: :export, get_by: [:case_number]
      define :list_sessions_for_export, action: :export_all
    end

    resource OwnershipAshChat.Study.Run do
      define :create_run, action: :create
      define :create_modification_run, action: :create_modification, args: [:session_id]
      define :get_run, action: :read, get_by: [:id]
      define :list_randomization_marks, action: :randomization_marks
      define :list_variant_marks, action: :variant_marks
      define :begin_run, action: :begin_run
      define :add_user_passage, action: :add_user_passage, args: [:text]
      define :submit_likert, action: :submit_likert
    end
  end
end
