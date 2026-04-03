namespace Cepaf.Planning

open System

type Priority =
    | P0_Critical
    | P1_High
    | P2_Medium
    | P3_Low
    | P4_Minimal
    | Unknown of string

    override this.ToString() =
        match this with
        | P0_Critical -> "P0"
        | P1_High -> "P1"
        | P2_Medium -> "P2"
        | P3_Low -> "P3"
        | P4_Minimal -> "P4"
        | Unknown s -> s

type TaskStatus =
    | Pending
    | InProgress
    | Completed
    | Blocked
    | Unknown of string

    override this.ToString() =
        match this with
        | Pending -> "pending"
        | InProgress -> "in_progress"
        | Completed -> "completed"
        | Blocked -> "blocked"
        | Unknown s -> s

type TaskId = string

type TaskItem = {
    Id: TaskId
    Title: string
    Status: TaskStatus
    Priority: Priority
    ParentId: TaskId option
    Owner: string option
    Created: DateTime
    RawLines: string list // For preserving formatting/comments
}

module DomainHelpers =
    let parsePriority (s: string) : Priority =
        match s.Trim().ToUpper() with
        | "P0" -> P0_Critical
        | "P1" -> P1_High
        | "P2" -> P2_Medium
        | "P3" -> P3_Low
        | "P4" -> P4_Minimal
        | _ -> Priority.Unknown s

    let parseStatus (s: string) =
        match s.Trim().ToLower() with
        | "pending" -> Pending
        | "in_progress" -> InProgress
        | "completed" -> Completed
        | "blocked" -> Blocked
        | _ -> Unknown s
