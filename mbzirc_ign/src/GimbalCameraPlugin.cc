/*
 * Copyright (C) 2022 Open Source Robotics Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#include <ignition/msgs/double.pb.h>

#include <memory>
#include <string>

#include <ignition/common/Console.hh>
#include <ignition/math/Angle.hh>
#include <ignition/plugin/Register.hh>
#include <ignition/transport/Node.hh>
#include <sdf/Camera.hh>

#include "ignition/gazebo/components/Camera.hh"
#include "ignition/gazebo/components/Name.hh"
#include "ignition/gazebo/components/ParentEntity.hh"
#include "ignition/gazebo/components/Sensor.hh"
#include "ignition/gazebo/Util.hh"

#include "GimbalCameraPlugin.hh"

using namespace ignition;
using namespace gazebo;
using namespace systems;
using namespace mbzirc;

/// \brief Private GimbalCameraPlugin data class.
class mbzirc::GimbalCameraPluginPrivate
{
  /// \brief Callback for HFOV command messages.
  /// \param[in] _msg Double message containing target HFOV value in degrees.
  public: void OnHfovCmd(const ignition::msgs::Double &_msg);

  /// \brief Camera entity.
  public: ignition::gazebo::Entity cameraEntity{ignition::gazebo::kNullEntity};

  /// \brief Camera link entity.
  public: ignition::gazebo::Entity cameraLinkEntity{ignition::gazebo::kNullEntity};

  /// \brief Model entity.
  public: ignition::gazebo::Entity modelEntity{ignition::gazebo::kNullEntity};

  /// \brief Ignition transport node for subscribing to HFOV commands.
  public: ignition::transport::Node node;

  /// \brief Current focal length in mm.
  public: double currentFocalLength{4.5};

  /// \brief Target focal length in mm.
  public: double targetFocalLength{4.5};

  /// \brief Minimum focal length in mm.
  public: double focalLengthMin{4.5};

  /// \brief Maximum focal length in mm.
  public: double focalLengthMax{135.0};

  /// \brief Focal length change rate in mm/sec (for 15s full range transition).
  public: double focalLengthRate{(135.0 - 4.5) / 15.0};

  /// \brief Sensor width in mm (standard 1/2.3" sensor ~ 6.17mm).
  public: double sensorWidth{6.17};

  /// \brief Name of the camera sensor.
  public: std::string sensorName{"camera"};

  /// \brief Whether a new HFOV command is pending.
  public: bool hfovCmdReceived{false};
};

/////////////////////////////////////////////////
GimbalCameraPlugin::GimbalCameraPlugin()
  : dataPtr(std::make_unique<GimbalCameraPluginPrivate>())
{
}

/////////////////////////////////////////////////
GimbalCameraPlugin::~GimbalCameraPlugin() = default;

/////////////////////////////////////////////////
void GimbalCameraPlugin::Configure(
    const ignition::gazebo::Entity &_entity,
    const std::shared_ptr<const sdf::Element> &_sdf,
    ignition::gazebo::EntityComponentManager &_ecm,
    ignition::gazebo::EventManager &/*_eventMgr*/)
{
  this->dataPtr->modelEntity = _entity;

  // Get camera link name from SDF
  std::string cameraLinkName = "sensor_link";
  if (_sdf->HasElement("camera_link"))
  {
    cameraLinkName = _sdf->Get<std::string>("camera_link");
  }

  // Get sensor name from SDF
  if (_sdf->HasElement("sensor_name"))
  {
    this->dataPtr->sensorName = _sdf->Get<std::string>("sensor_name");
  }

  // Get focal length range from SDF
  if (_sdf->HasElement("focal_length_min"))
  {
    this->dataPtr->focalLengthMin = _sdf->Get<double>("focal_length_min");
  }
  if (_sdf->HasElement("focal_length_max"))
  {
    this->dataPtr->focalLengthMax = _sdf->Get<double>("focal_length_max");
  }

  // Get transition time from SDF (optional)
  if (_sdf->HasElement("transition_time"))
  {
    double transitionTime = _sdf->Get<double>("transition_time");
    if (transitionTime > 0)
    {
      this->dataPtr->focalLengthRate =
          (this->dataPtr->focalLengthMax - this->dataPtr->focalLengthMin) / transitionTime;
    }
  }

  // Get sensor width from SDF (optional)
  if (_sdf->HasElement("sensor_width"))
  {
    this->dataPtr->sensorWidth = _sdf->Get<double>("sensor_width");
  }

  // Find camera link entity
  this->dataPtr->cameraLinkEntity = _ecm.EntityByComponents(
      ignition::gazebo::components::Name(cameraLinkName),
      ignition::gazebo::components::ParentEntity(this->dataPtr->modelEntity));

  if (this->dataPtr->cameraLinkEntity == ignition::gazebo::kNullEntity)
  {
    ignerr << "GimbalCameraPlugin: Camera link '" << cameraLinkName
           << "' not found!" << std::endl;
    return;
  }

  // Find camera sensor entity
  this->dataPtr->cameraEntity = _ecm.EntityByComponents(
      ignition::gazebo::components::Name(this->dataPtr->sensorName),
      ignition::gazebo::components::Sensor(),
      ignition::gazebo::components::ParentEntity(this->dataPtr->cameraLinkEntity));

  if (this->dataPtr->cameraEntity == ignition::gazebo::kNullEntity)
  {
    ignerr << "GimbalCameraPlugin: Camera sensor '" << this->dataPtr->sensorName
           << "' not found!" << std::endl;
    return;
  }

  // Get initial focal length from current HFOV
  auto cameraComp = _ecm.Component<ignition::gazebo::components::Camera>(
      this->dataPtr->cameraEntity);
  if (cameraComp)
  {
    const sdf::Sensor &sensor = cameraComp->Data();
    if (sensor.Type() == sdf::SensorType::CAMERA)
    {
      const sdf::Camera *cam = sensor.CameraSensor();
      if (cam)
      {
        // Calculate initial focal length from HFOV: f = w / (2 * tan(HFOV/2))
        double hfov = cam->HorizontalFov().Radian();
        this->dataPtr->currentFocalLength =
            this->dataPtr->sensorWidth / (2.0 * std::tan(hfov / 2.0));
        this->dataPtr->targetFocalLength = this->dataPtr->currentFocalLength;
      }
    }
  }

  // Get HFOV topic name from SDF
  std::string hfovTopic = "~/gimbal/set_hfov";
  if (_sdf->HasElement("hfov_topic"))
  {
    hfovTopic = _sdf->Get<std::string>("hfov_topic");
  }

  // Subscribe to HFOV command topic
  this->dataPtr->node.Subscribe(hfovTopic,
      &GimbalCameraPluginPrivate::OnHfovCmd, this->dataPtr.get());

  ignmsg << "GimbalCameraPlugin configured:" << std::endl
         << "  Focal length range: " << this->dataPtr->focalLengthMin
         << " - " << this->dataPtr->focalLengthMax << " mm" << std::endl
         << "  Change rate: " << this->dataPtr->focalLengthRate << " mm/sec" << std::endl
         << "  Full transition time: ~"
         << (this->dataPtr->focalLengthMax - this->dataPtr->focalLengthMin) /
            this->dataPtr->focalLengthRate << " seconds" << std::endl;
}

/////////////////////////////////////////////////
void GimbalCameraPluginPrivate::OnHfovCmd(const ignition::msgs::Double &_msg)
{
  // Convert HFOV (degrees) to focal length (mm)
  // HFOV = 2 * atan(w / (2*f))  =>  f = w / (2 * tan(HFOV/2))
  double hfovRad = ignition::math::Angle(_msg.data()).Radian();
  double focalLength = this->sensorWidth / (2.0 * std::tan(hfovRad / 2.0));

  // Clamp to valid range
  this->targetFocalLength = ignition::math::clamp(focalLength,
      this->focalLengthMin, this->focalLengthMax);
  this->hfovCmdReceived = true;

  // Calculate resulting HFOV for feedback
  double resultHfovRad = 2.0 * std::atan(this->sensorWidth / (2.0 * this->targetFocalLength));
  double resultHfovDeg = ignition::math::Angle(resultHfovRad).Degree();

  igndbg << "HFOV command: " << _msg.data() << " deg"
         << " (clamped to " << resultHfovDeg << " deg, "
         << "f = " << this->targetFocalLength << " mm)" << std::endl;
}

/////////////////////////////////////////////////
void GimbalCameraPlugin::PreUpdate(
    const ignition::gazebo::UpdateInfo &_info,
    ignition::gazebo::EntityComponentManager &_ecm)
{
  if (this->dataPtr->cameraEntity == ignition::gazebo::kNullEntity)
  {
    return;
  }

  // Update focal length with fixed rate
  if (this->dataPtr->hfovCmdReceived)
  {
    double diff = this->dataPtr->targetFocalLength - this->dataPtr->currentFocalLength;
    double maxChange = this->dataPtr->focalLengthRate *
        std::chrono::duration<double>(_info.dt).count();

    if (std::abs(diff) <= maxChange)
    {
      // Reached target
      this->dataPtr->currentFocalLength = this->dataPtr->targetFocalLength;
      this->dataPtr->hfovCmdReceived = false;

      igndbg << "HFOV transition complete. Current focal length: "
             << this->dataPtr->currentFocalLength << " mm" << std::endl;
    }
    else
    {
      // Move toward target at fixed rate
      double direction = (diff > 0) ? 1.0 : -1.0;
      this->dataPtr->currentFocalLength += direction * maxChange;
    }

    // Calculate current HFOV from focal length
    double currentHfovRad = 2.0 * std::atan(
        this->dataPtr->sensorWidth / (2.0 * this->dataPtr->currentFocalLength));
    double currentHfovDeg = ignition::math::Angle(currentHfovRad).Degree();

    // Note: Ignition Fortress doesn't support runtime HFOV modification
    // The plugin tracks the zoom state for potential future use
    igndbg << "Zoom state: f = " << this->dataPtr->currentFocalLength
           << " mm, HFOV = " << currentHfovDeg << " deg" << std::endl;
  }
}

IGNITION_ADD_PLUGIN(mbzirc::GimbalCameraPlugin,
                    ignition::gazebo::System,
                    mbzirc::GimbalCameraPlugin::ISystemConfigure,
                    mbzirc::GimbalCameraPlugin::ISystemPreUpdate)

IGNITION_ADD_PLUGIN_ALIAS(mbzirc::GimbalCameraPlugin,
                          "ignition::gazebo::systems::GimbalCameraPlugin")
