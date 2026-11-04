using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace StickDrift.EditorTools
{
    /// <summary>
    /// One-click setup: Stick Drift > Build Neighborhood Scene.
    /// Creates the material templates, a scene with the bootstrap object, adds it to the build,
    /// and sets the iPhone player settings (landscape only, bundle id, etc).
    /// </summary>
    public static class StickDriftSetup
    {
        const string ScenePath = "Assets/Scenes/Neighborhood.unity";

        [MenuItem("Stick Drift/Build Neighborhood Scene")]
        public static void BuildScene()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;

            EnsureFolder("Assets", "Scenes");
            EnsureFolder("Assets", "Materials");

            var lit = MakeMaterial("Assets/Materials/SD_Lit.mat", "Standard", false);
            var emissive = MakeMaterial("Assets/Materials/SD_LitEmissive.mat", "Standard", true);
            var glow = MakeMaterial("Assets/Materials/SD_Glow.mat", "Sprites/Default", false);

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var go = new GameObject("Stick Drift");
            var boot = go.AddComponent<StickDriftBootstrap>();
            boot.litTemplate = lit;
            boot.emissiveTemplate = emissive;
            boot.glowTemplate = glow;

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };

            ApplyPlayerSettings();
            Debug.Log("Stick Drift: scene built at " + ScenePath + ". Hit Play.");
        }

        [MenuItem("Stick Drift/Apply iPhone Player Settings")]
        public static void ApplyPlayerSettings()
        {
            PlayerSettings.productName = "Stick Drift";
            PlayerSettings.companyName = "StoneColdOS";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS, "com.stonecoldos.stickdrift");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.statusBarHidden = true;
        }

        static Material MakeMaterial(string path, string shaderName, bool emissive)
        {
            var existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing != null) return existing;

            var shader = Shader.Find(shaderName);
            if (shader == null)
            {
                Debug.LogError($"Stick Drift: shader '{shaderName}' not found. This project expects the Built-in Render Pipeline (not URP/HDRP).");
                return null;
            }

            var mat = new Material(shader);
            if (emissive)
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", Color.white);
                mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.None;
            }
            AssetDatabase.CreateAsset(mat, path);
            AssetDatabase.SaveAssets();
            return mat;
        }

        static void EnsureFolder(string parent, string name)
        {
            if (!AssetDatabase.IsValidFolder(parent + "/" + name))
                AssetDatabase.CreateFolder(parent, name);
        }
    }
}
