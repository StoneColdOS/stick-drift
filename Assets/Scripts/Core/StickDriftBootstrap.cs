using System.Collections.Generic;
using UnityEngine;
using StickDrift.Car;
using StickDrift.Rendering;
using StickDrift.UI;
using StickDrift.World;

namespace StickDrift
{
    /// <summary>
    /// Builds the whole game at startup: night lighting, the neighborhood, the car, the camera
    /// and the touch controls. The scene only needs this one object (Stick Drift > Build Neighborhood Scene).
    /// </summary>
    public class StickDriftBootstrap : MonoBehaviour
    {
        [Header("Material templates (filled in by Stick Drift > Build Neighborhood Scene)")]
        public Material litTemplate;
        public Material emissiveTemplate;
        public Material glowTemplate;

        [Header("World")]
        public int seed = 86;
        public Color nightSky = new Color(0.035f, 0.045f, 0.08f);
        [Range(120, 720)] public int pixelHeight = 270;

        void Awake()
        {
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Screen.autorotateToPortrait = false;
            Screen.autorotateToPortraitUpsideDown = false;
            Screen.autorotateToLandscapeLeft = true;
            Screen.autorotateToLandscapeRight = true;
            Screen.orientation = ScreenOrientation.AutoRotation;
            QualitySettings.pixelLightCount = 6;
            Time.fixedDeltaTime = 1f / 100f;

            MatLib.Init(litTemplate, emissiveTemplate, glowTemplate);
            SetupNight();

            var lights = new List<Light>();
            var spawn = NeighborhoodBuilder.Build(transform, seed, lights);

            var controls = gameObject.AddComponent<CarControls>();
            var car = CarBuilder.Build(spawn, controls);

            var culler = gameObject.AddComponent<LampCuller>();
            culler.target = car.transform;
            culler.lights = lights;

            var worldImage = UIBuilder.Build(controls, car);
            BuildCameras(car, worldImage);
        }

        void SetupNight()
        {
            RenderSettings.skybox = null;
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.09f, 0.10f, 0.15f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = nightSky;
            RenderSettings.fogStartDistance = 45f;
            RenderSettings.fogEndDistance = 120f;

            var moon = new GameObject("Moon").AddComponent<Light>();
            moon.type = LightType.Directional;
            moon.color = new Color(0.55f, 0.62f, 0.85f);
            moon.intensity = 0.12f;
            moon.shadows = LightShadows.None;
            moon.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
        }

        void BuildCameras(DriftCar car, UnityEngine.UI.RawImage worldImage)
        {
            // Clears the actual screen; everything visible comes from the pixel render texture + UI.
            var clear = new GameObject("Screen Clear").AddComponent<Camera>();
            clear.clearFlags = CameraClearFlags.SolidColor;
            clear.backgroundColor = Color.black;
            clear.cullingMask = 0;
            clear.depth = -100;

            var camGo = new GameObject("Main Camera");
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = nightSky;
            cam.fieldOfView = 38f;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 300f;
            cam.allowMSAA = false;
            camGo.AddComponent<AudioListener>();

            var follow = camGo.AddComponent<FollowCamera>();
            follow.car = car;

            var pixel = camGo.AddComponent<PixelCamera>();
            pixel.output = worldImage;
            pixel.targetHeight = pixelHeight;
        }
    }
}
