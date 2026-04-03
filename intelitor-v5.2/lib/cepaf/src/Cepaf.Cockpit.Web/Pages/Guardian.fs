namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I - Guardian Page (Constitutional Safety Kernel)
/// =============================================================================
/// STAMP: SC-PRAJNA-001 (Guardian validation), SC-CONST-001 (Constitutional check)
/// =============================================================================

module Guardian =

    type GuardianFilter =
        | AllProposals
        | PendingOnly
        | ApprovedOnly
        | VetoedOnly

    type GuardianModel = {
        Filter: GuardianFilter
        SelectedProposal: string option
        VetoReason: string
    }

    type GuardianMsg =
        | SetFilter of GuardianFilter
        | SelectProposal of string option
        | SetVetoReason of string
        | ConfirmVeto of string

    let init () = {
        Filter = PendingOnly
        SelectedProposal = None
        VetoReason = ""
    }

    let update (msg: GuardianMsg) (model: GuardianModel) (dispatch: Message -> unit) =
        match msg with
        | SetFilter filter -> { model with Filter = filter }
        | SelectProposal id -> { model with SelectedProposal = id; VetoReason = "" }
        | SetVetoReason reason -> { model with VetoReason = reason }
        | ConfirmVeto proposalId ->
            if not (String.IsNullOrWhiteSpace model.VetoReason) then
                dispatch (VetoProposal (proposalId, model.VetoReason))
            { model with VetoReason = ""; SelectedProposal = None }

    let private getSeverityColor (severity: AlarmLevel) =
        match severity with
        | AlarmLevel.Critical -> "#dc2626"
        | AlarmLevel.Warning -> "#f59e0b"
        | AlarmLevel.Caution -> "#fbbf24"
        | AlarmLevel.Advisory -> "#06b6d4"
        | AlarmLevel.Normal -> "#6b7280"

    let private renderProposalCard (proposal: GuardianProposal) (isSelected: bool) (localDispatch: GuardianMsg -> unit) (dispatch: Message -> unit) =
        let severityColor = getSeverityColor proposal.Severity
        let voteProgress = float proposal.Votes / float proposal.RequiredVotes * 100.0
        let cardClass = if isSelected then "proposal-card selected" else "proposal-card"

        div {
            attr.``class`` cardClass
            attr.style (sprintf "border-left: 4px solid %s;" severityColor)
            on.click (fun _ -> localDispatch (SelectProposal (Some proposal.Id)))
            div {
                attr.``class`` "proposal-header"
                span {
                    attr.``class`` "proposal-title"
                    text proposal.Title
                }
                span {
                    attr.``class`` "proposal-category"
                    attr.style (sprintf "color: %s;" severityColor)
                    text proposal.Category
                }
            }
            div {
                attr.``class`` "proposal-description"
                text proposal.Description
            }
            div {
                attr.``class`` "proposal-meta"
                span {
                    attr.``class`` "proposal-by"
                    text (sprintf "Proposed by: %s" proposal.ProposedBy)
                }
                span {
                    attr.``class`` "proposal-time"
                    text (proposal.ProposedAt.ToString("yyyy-MM-dd HH:mm"))
                }
            }
            div {
                attr.``class`` "proposal-votes"
                div {
                    attr.``class`` "vote-progress"
                    div {
                        attr.``class`` "vote-bar"
                        attr.style (sprintf "width: %.1f%%;" voteProgress)
                    }
                }
                span {
                    attr.``class`` "vote-count"
                    text (sprintf "%d / %d votes" proposal.Votes proposal.RequiredVotes)
                }
            }
            div {
                attr.``class`` "proposal-actions"
                button {
                    attr.``class`` "btn-approve"
                    on.click (fun _ -> dispatch (ApproveProposal proposal.Id))
                    text "Approve"
                }
                button {
                    attr.``class`` "btn-veto"
                    on.click (fun _ -> localDispatch (SelectProposal (Some proposal.Id)))
                    text "Veto"
                }
            }
        }

    let private renderVetoModal (proposalId: string) (reason: string) (localDispatch: GuardianMsg -> unit) =
        div {
            attr.``class`` "modal-overlay"
            div {
                attr.``class`` "modal-content veto-modal"
                h3 { text "Veto Proposal" }
                p { text "Please provide a reason for vetoing this proposal:" }
                textarea {
                    attr.``class`` "veto-reason-input"
                    attr.placeholder "Enter veto reason..."
                    attr.value reason
                    on.input (fun e -> localDispatch (SetVetoReason (e.Value :?> string)))
                }
                div {
                    attr.``class`` "modal-actions"
                    button {
                        attr.``class`` "btn-cancel"
                        on.click (fun _ -> localDispatch (SelectProposal None))
                        text "Cancel"
                    }
                    button {
                        attr.``class`` "btn-confirm-veto"
                        attr.disabled (String.IsNullOrWhiteSpace reason)
                        on.click (fun _ -> localDispatch (ConfirmVeto proposalId))
                        text "Confirm Veto"
                    }
                }
            }
        }

    let private renderFilterButtons (currentFilter: GuardianFilter) (localDispatch: GuardianMsg -> unit) =
        div {
            attr.``class`` "filter-buttons"
            button {
                attr.``class`` (if currentFilter = AllProposals then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter AllProposals))
                text "All"
            }
            button {
                attr.``class`` (if currentFilter = PendingOnly then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter PendingOnly))
                text "Pending"
            }
        }

    let view (appModel: Model.AppModel) (localModel: GuardianModel) (localDispatch: GuardianMsg -> unit) (dispatch: Message -> unit) =
        let filteredProposals =
            match localModel.Filter with
            | AllProposals -> appModel.Proposals
            | PendingOnly -> appModel.Proposals |> List.filter (fun p -> p.RequiresApproval)
            | ApprovedOnly -> appModel.Proposals |> List.filter (fun p -> p.Votes >= p.RequiredVotes)
            | VetoedOnly -> []

        let pendingCount = appModel.Proposals |> List.filter (fun p -> p.RequiresApproval) |> List.length

        div {
            attr.``class`` "page-guardian"
            div {
                attr.``class`` "page-header"
                h1 { text "Guardian - Constitutional Safety Kernel" }
                div {
                    attr.``class`` "guardian-summary"
                    span {
                        attr.``class`` "summary-item pending"
                        text (sprintf "%d Pending Proposals" pendingCount)
                    }
                }
            }

            div {
                attr.``class`` "guardian-toolbar"
                renderFilterButtons localModel.Filter localDispatch
            }

            div {
                attr.``class`` "proposals-grid"
                if List.isEmpty filteredProposals then
                    div {
                        attr.``class`` "no-proposals"
                        text "No proposals match the current filter"
                    }
                else
                    forEach filteredProposals (fun proposal ->
                        let isSelected = localModel.SelectedProposal = Some proposal.Id
                        renderProposalCard proposal isSelected localDispatch dispatch
                    )
            }

            match localModel.SelectedProposal with
            | Some proposalId when not (String.IsNullOrWhiteSpace localModel.VetoReason) || localModel.SelectedProposal.IsSome ->
                renderVetoModal proposalId localModel.VetoReason localDispatch
            | _ -> empty ()
        }

type GuardianComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Guardian.init ()
    let mutable lastDispatch: (Message -> unit) option = None

    let localDispatch (msg: Guardian.GuardianMsg) =
        match lastDispatch with
        | Some dispatch -> localModel <- Guardian.update msg localModel dispatch
        | None -> localModel <- Guardian.update msg localModel ignore

    override this.View model dispatch =
        lastDispatch <- Some dispatch
        Guardian.view model localModel localDispatch dispatch
