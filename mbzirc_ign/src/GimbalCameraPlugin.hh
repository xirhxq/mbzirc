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
#ifndef MBZIRC_IGN_GIMBALCAMERAPLUGIN_HH_
#define MBZIRC_IGN_GIMBALCAMERAPLUGIN_HH_

#include <memory>
#include <ignition/gazebo/System.hh>
#include <ignition/gazebo/components/Component.hh>
#include <ignition/plugin/Register.hh>
#include <sdf/Element.hh>

namespace mbzirc
{
// Forward declaration.
class GimbalCameraPluginPrivate;

/// \brief A model plugin for controlling camera HFOV (zoom) with dynamics.
///
/// This plugin provides smooth HFOV transitions with fixed focal length change rate,
/// simulating realistic zoom lens behavior.
///
/// ## Configuration Parameters
///
/// * <camera_link>: Name of the link containing the camera sensor. [string, default: "sensor_link"]
/// * <sensor_name>: Name of the camera sensor. [string, default: "camera"]
/// * <focal_length_min>: Minimum focal length in mm. [double, default: 4.5]
/// * <focal_length_max>: Maximum focal length in mm. [double, default: 135.0]
/// * <transition_time>: Time for full range transition in seconds. [double, default: 15.0]
/// * <sensor_width>: Sensor width in mm for HFOV calculation. [double, default: 6.17]
/// * <hfov_topic>: Topic for receiving HFOV commands. [string, default: "~/gimbal/set_hfov"]
///
/// ## Subscribed Topics
///
/// * <hfov_topic>: Receives std_msgs::Float64 with desired HFOV in degrees.
///
/// ## Dynamics
///
/// Focal length changes at a fixed rate: (f_max - f_min) / transition_time
/// Default: (135 - 4.5) / 15 = 8.7 mm/sec
///
/// ## Example Usage
///
/// <plugin filename="libGimbalCameraPlugin.so"
///         name="mbzirc::GimbalCameraPlugin">
///   <camera_link>sensor_link</camera_link>
///   <sensor_name>camera</sensor_name>
///   <focal_length_min>4.5</focal_length_min>
///   <focal_length_max>135.0</focal_length_max>
///   <transition_time>15.0</transition_time>
///   <hfov_topic>~/gimbal/set_hfov</hfov_topic>
/// </plugin>
class GimbalCameraPlugin
    : public ignition::gazebo::System,
      public ignition::gazebo::ISystemConfigure,
      public ignition::gazebo::ISystemPreUpdate
{
  /// \brief Constructor.
  public: GimbalCameraPlugin();

  /// \brief Destructor.
  public: ~GimbalCameraPlugin() override;

  // Documentation inherited.
  public: void Configure(const ignition::gazebo::Entity &_entity,
                         const std::shared_ptr<const sdf::Element> &_sdf,
                         ignition::gazebo::EntityComponentManager &_ecm,
                         ignition::gazebo::EventManager &_eventMgr) override;

  // Documentation inherited.
  public: void PreUpdate(
              const ignition::gazebo::UpdateInfo &_info,
              ignition::gazebo::EntityComponentManager &_ecm) override;

  /// \brief Private data pointer.
  private: std::unique_ptr<GimbalCameraPluginPrivate> dataPtr;
};

}  // namespace mbzirc

#endif
