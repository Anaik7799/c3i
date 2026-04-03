/// Lustre component for Podman plane (SC-GLM-UI-001).
/// Manages container, image, volume, and network state from Podman API.
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009
import gleam/list

pub type PodmanModel {
  PodmanModel(
    containers: List(Container),
    images: List(Image),
    volumes: List(Volume),
    networks: List(Network),
  )
}

pub type Container {
  Container(id: String, name: String, status: String, image: String)
}

pub type Image {
  Image(id: String, repository: String, tag: String, size_mb: Int)
}

pub type Volume {
  Volume(name: String, driver: String, mountpoint: String)
}

pub type Network {
  Network(name: String, driver: String, subnet: String)
}

pub type PodmanMsg {
  ContainersLoaded(List(Container))
  ImagesLoaded(List(Image))
  StartContainer(String)
  StopContainer(String)
  RefreshPodman
}

pub fn init() -> PodmanModel {
  PodmanModel(containers: [], images: [], volumes: [], networks: [])
}

pub fn update(model: PodmanModel, msg: PodmanMsg) -> PodmanModel {
  case msg {
    ContainersLoaded(cs) -> PodmanModel(..model, containers: cs)
    ImagesLoaded(imgs) -> PodmanModel(..model, images: imgs)
    StartContainer(_id) -> model
    StopContainer(_id) -> model
    RefreshPodman -> model
  }
}

pub fn running_containers(model: PodmanModel) -> List(Container) {
  list.filter(model.containers, fn(c) { c.status == "running" })
}

pub fn container_count(model: PodmanModel) -> Int {
  list.length(model.containers)
}

pub fn running_count(model: PodmanModel) -> Int {
  list.length(running_containers(model))
}
