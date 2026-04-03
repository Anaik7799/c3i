namespace Cepaf.Podman.Domain

open System

// ============================================================================
// Event Types
// ============================================================================

/// Event type category
[<RequireQualifiedAccess>]
type EventType =
    | Container
    | Image
    | Pod
    | Volume
    | Network
    | System
    | Unknown of string

module EventType =
    let parse (t: string) : EventType =
        match t.ToLowerInvariant() with
        | "container" -> EventType.Container
        | "image" -> EventType.Image
        | "pod" -> EventType.Pod
        | "volume" -> EventType.Volume
        | "network" -> EventType.Network
        | "system" -> EventType.System
        | s -> EventType.Unknown s

    let toString (t: EventType) : string =
        match t with
        | EventType.Container -> "container"
        | EventType.Image -> "image"
        | EventType.Pod -> "pod"
        | EventType.Volume -> "volume"
        | EventType.Network -> "network"
        | EventType.System -> "system"
        | EventType.Unknown s -> s

/// Container event actions
[<RequireQualifiedAccess>]
type ContainerAction =
    | Attach
    | Checkpoint
    | Cleanup
    | Commit
    | Create
    | Exec
    | ExecDied
    | Export
    | Import
    | Init
    | Kill
    | Mount
    | Pause
    | Prune
    | Remove
    | Rename
    | Restart
    | Restore
    | Start
    | Stop
    | Sync
    | Unmount
    | Unpause
    | Update
    | Unknown of string

module ContainerAction =
    let parse (action: string) : ContainerAction =
        match action.ToLowerInvariant() with
        | "attach" -> ContainerAction.Attach
        | "checkpoint" -> ContainerAction.Checkpoint
        | "cleanup" -> ContainerAction.Cleanup
        | "commit" -> ContainerAction.Commit
        | "create" -> ContainerAction.Create
        | "exec" -> ContainerAction.Exec
        | "exec_died" -> ContainerAction.ExecDied
        | "export" -> ContainerAction.Export
        | "import" -> ContainerAction.Import
        | "init" -> ContainerAction.Init
        | "kill" -> ContainerAction.Kill
        | "mount" -> ContainerAction.Mount
        | "pause" -> ContainerAction.Pause
        | "prune" -> ContainerAction.Prune
        | "remove" -> ContainerAction.Remove
        | "rename" -> ContainerAction.Rename
        | "restart" -> ContainerAction.Restart
        | "restore" -> ContainerAction.Restore
        | "start" -> ContainerAction.Start
        | "stop" -> ContainerAction.Stop
        | "sync" -> ContainerAction.Sync
        | "unmount" -> ContainerAction.Unmount
        | "unpause" -> ContainerAction.Unpause
        | "update" -> ContainerAction.Update
        | s -> ContainerAction.Unknown s

    let toString (action: ContainerAction) : string =
        match action with
        | ContainerAction.Attach -> "attach"
        | ContainerAction.Checkpoint -> "checkpoint"
        | ContainerAction.Cleanup -> "cleanup"
        | ContainerAction.Commit -> "commit"
        | ContainerAction.Create -> "create"
        | ContainerAction.Exec -> "exec"
        | ContainerAction.ExecDied -> "exec_died"
        | ContainerAction.Export -> "export"
        | ContainerAction.Import -> "import"
        | ContainerAction.Init -> "init"
        | ContainerAction.Kill -> "kill"
        | ContainerAction.Mount -> "mount"
        | ContainerAction.Pause -> "pause"
        | ContainerAction.Prune -> "prune"
        | ContainerAction.Remove -> "remove"
        | ContainerAction.Rename -> "rename"
        | ContainerAction.Restart -> "restart"
        | ContainerAction.Restore -> "restore"
        | ContainerAction.Start -> "start"
        | ContainerAction.Stop -> "stop"
        | ContainerAction.Sync -> "sync"
        | ContainerAction.Unmount -> "unmount"
        | ContainerAction.Unpause -> "unpause"
        | ContainerAction.Update -> "update"
        | ContainerAction.Unknown s -> s

/// Image event actions
[<RequireQualifiedAccess>]
type ImageAction =
    | Build
    | Import
    | Load
    | Pull
    | Push
    | Remove
    | Save
    | Tag
    | Untag
    | Unknown of string

module ImageAction =
    let parse (action: string) : ImageAction =
        match action.ToLowerInvariant() with
        | "build" -> ImageAction.Build
        | "import" -> ImageAction.Import
        | "load" -> ImageAction.Load
        | "pull" -> ImageAction.Pull
        | "push" -> ImageAction.Push
        | "remove" -> ImageAction.Remove
        | "save" -> ImageAction.Save
        | "tag" -> ImageAction.Tag
        | "untag" -> ImageAction.Untag
        | s -> ImageAction.Unknown s

/// Pod event actions
[<RequireQualifiedAccess>]
type PodAction =
    | Create
    | Kill
    | Pause
    | Remove
    | Start
    | Stop
    | Unpause
    | Unknown of string

module PodAction =
    let parse (action: string) : PodAction =
        match action.ToLowerInvariant() with
        | "create" -> PodAction.Create
        | "kill" -> PodAction.Kill
        | "pause" -> PodAction.Pause
        | "remove" -> PodAction.Remove
        | "start" -> PodAction.Start
        | "stop" -> PodAction.Stop
        | "unpause" -> PodAction.Unpause
        | s -> PodAction.Unknown s

/// Volume event actions
[<RequireQualifiedAccess>]
type VolumeAction =
    | Create
    | Prune
    | Remove
    | Unknown of string

module VolumeAction =
    let parse (action: string) : VolumeAction =
        match action.ToLowerInvariant() with
        | "create" -> VolumeAction.Create
        | "prune" -> VolumeAction.Prune
        | "remove" -> VolumeAction.Remove
        | s -> VolumeAction.Unknown s

/// Network event actions
[<RequireQualifiedAccess>]
type NetworkAction =
    | Connect
    | Create
    | Disconnect
    | Remove
    | Unknown of string

module NetworkAction =
    let parse (action: string) : NetworkAction =
        match action.ToLowerInvariant() with
        | "connect" -> NetworkAction.Connect
        | "create" -> NetworkAction.Create
        | "disconnect" -> NetworkAction.Disconnect
        | "remove" -> NetworkAction.Remove
        | s -> NetworkAction.Unknown s

/// Event actor (the resource affected)
type EventActor = {
    ID: string
    Attributes: Map<string, string>
}

module EventActor =
    let empty = { ID = ""; Attributes = Map.empty }

    let getName (actor: EventActor) : string option =
        actor.Attributes |> Map.tryFind "name"

    let getImage (actor: EventActor) : string option =
        actor.Attributes |> Map.tryFind "image"

    let getContainerId (actor: EventActor) : string option =
        actor.Attributes |> Map.tryFind "containerID"

/// Podman event
type PodmanEvent = {
    Type: EventType
    Action: string
    Actor: EventActor
    Time: int64
    TimeNano: int64
    Status: string option
}

module PodmanEvent =

    /// Get event timestamp as DateTimeOffset
    let getTimestamp (event: PodmanEvent) : DateTimeOffset =
        DateTimeOffset.FromUnixTimeSeconds(event.Time)

    /// Check if event is for a specific container
    let isForContainer (containerId: string) (event: PodmanEvent) : bool =
        event.Type = EventType.Container && event.Actor.ID.StartsWith(containerId)

    /// Check if event is for a specific action
    let isAction (action: string) (event: PodmanEvent) : bool =
        event.Action.Equals(action, StringComparison.OrdinalIgnoreCase)

    /// Get container action if applicable
    let getContainerAction (event: PodmanEvent) : ContainerAction option =
        if event.Type = EventType.Container then
            Some (ContainerAction.parse event.Action)
        else
            None

    /// Get image action if applicable
    let getImageAction (event: PodmanEvent) : ImageAction option =
        if event.Type = EventType.Image then
            Some (ImageAction.parse event.Action)
        else
            None

    /// Get pod action if applicable
    let getPodAction (event: PodmanEvent) : PodAction option =
        if event.Type = EventType.Pod then
            Some (PodAction.parse event.Action)
        else
            None

// ============================================================================
// Event Filter
// ============================================================================

/// Event filter configuration
type EventFilter = {
    Containers: string list
    Events: string list
    Images: string list
    Pods: string list
    Volumes: string list
    Types: EventType list
    Since: DateTimeOffset option
    Until: DateTimeOffset option
}

module EventFilter =

    /// Empty filter (matches all events)
    let empty = {
        Containers = []
        Events = []
        Images = []
        Pods = []
        Volumes = []
        Types = []
        Since = None
        Until = None
    }

    /// Filter for specific container
    let forContainer id filter =
        { filter with Containers = id :: filter.Containers }

    /// Filter for specific containers
    let forContainers ids filter =
        { filter with Containers = ids @ filter.Containers }

    /// Filter for specific event actions
    let forEvents events filter =
        { filter with Events = events @ filter.Events }

    /// Filter for specific event types
    let forTypes types filter =
        { filter with Types = types @ filter.Types }

    /// Filter for container events only
    let containerEvents filter =
        { filter with Types = EventType.Container :: filter.Types }

    /// Filter for image events only
    let imageEvents filter =
        { filter with Types = EventType.Image :: filter.Types }

    /// Filter for pod events only
    let podEvents filter =
        { filter with Types = EventType.Pod :: filter.Types }

    /// Filter for specific image
    let forImage id filter =
        { filter with Images = id :: filter.Images }

    /// Filter for specific pod
    let forPod name filter =
        { filter with Pods = name :: filter.Pods }

    /// Filter for specific volume
    let forVolume name filter =
        { filter with Volumes = name :: filter.Volumes }

    /// Filter events since timestamp
    let since timestamp filter =
        { filter with Since = Some timestamp }

    /// Filter events until timestamp
    let until timestamp filter =
        { filter with Until = Some timestamp }

    /// Build query string for filter
    let toQueryString (filter: EventFilter) : string =
        let parts = [
            if not filter.Containers.IsEmpty then
                for c in filter.Containers do
                    yield sprintf "container=%s" c
            if not filter.Events.IsEmpty then
                for e in filter.Events do
                    yield sprintf "event=%s" e
            if not filter.Images.IsEmpty then
                for i in filter.Images do
                    yield sprintf "image=%s" i
            if not filter.Types.IsEmpty then
                for t in filter.Types do
                    yield sprintf "type=%s" (EventType.toString t)
            match filter.Since with
            | Some s -> yield sprintf "since=%d" (s.ToUnixTimeSeconds())
            | None -> ()
            match filter.Until with
            | Some u -> yield sprintf "until=%d" (u.ToUnixTimeSeconds())
            | None -> ()
        ]
        if parts.IsEmpty then ""
        else "?" + String.concat "&" parts

// ============================================================================
// Event Subscription
// ============================================================================

/// Event handler callback
type EventHandler = PodmanEvent -> unit

/// Event subscription options
type EventSubscriptionOptions = {
    Filter: EventFilter
    BufferSize: int
    ReconnectOnError: bool
    ReconnectDelay: TimeSpan
}

module EventSubscriptionOptions =
    let defaults = {
        Filter = EventFilter.empty
        BufferSize = 100
        ReconnectOnError = true
        ReconnectDelay = TimeSpan.FromSeconds(5.0)
    }

    let withFilter filter opts = { opts with Filter = filter }
    let withBufferSize size opts = { opts with BufferSize = size }
    let withoutReconnect opts = { opts with ReconnectOnError = false }
    let withReconnectDelay delay opts = { opts with ReconnectDelay = delay }
