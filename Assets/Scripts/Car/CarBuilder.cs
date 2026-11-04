using UnityEngine;
using StickDrift.World;
using static StickDrift.World.MeshFactory;

namespace StickDrift.Car
{
    /// <summary>
    /// Builds the car: physics root plus a blocky, two-tone ("panda") old-school coupe.
    /// Swap the Visual child for a real low-poly model later; the physics doesn't care.
    /// </summary>
    public static class CarBuilder
    {
        static readonly Color White = new Color(0.92f, 0.92f, 0.90f);
        static readonly Color Black = new Color(0.05f, 0.05f, 0.06f);
        static readonly Color GlassC = new Color(0.05f, 0.07f, 0.10f);
        static readonly Color Tire = new Color(0.04f, 0.04f, 0.04f);
        static readonly Color Headlight = new Color(1f, 0.93f, 0.8f);

        public static DriftCar Build(SpawnPoint spawn, CarControls controls)
        {
            var go = new GameObject("Car");
            go.transform.SetPositionAndRotation(spawn.position, spawn.rotation);

            var col = go.AddComponent<BoxCollider>();
            col.center = new Vector3(0f, 0.65f, 0f);
            col.size = new Vector3(1.66f, 0.9f, 4.2f);
            col.material = new PhysicsMaterial("Car")
            {
                dynamicFriction = 0.1f,
                staticFriction = 0.1f,
                bounciness = 0.15f,
                frictionCombine = PhysicsMaterialCombine.Minimum,
                bounceCombine = PhysicsMaterialCombine.Average
            };

            var rb = go.AddComponent<Rigidbody>();
            rb.mass = 1000f;
            rb.useGravity = false;
            rb.linearDamping = 0f;
            rb.angularDamping = 0.5f;
            rb.interpolation = RigidbodyInterpolation.Interpolate;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            rb.constraints = RigidbodyConstraints.FreezePositionY | RigidbodyConstraints.FreezeRotationX | RigidbodyConstraints.FreezeRotationZ;
            rb.centerOfMass = new Vector3(0f, 0.5f, -0.1f);

            var car = go.AddComponent<DriftCar>();
            car.controls = controls;

            var vis = new GameObject("Visual").transform;
            vis.SetParent(go.transform, false);

            var white = MatLib.Lit(White, 0.65f);
            var black = MatLib.Lit(Black, 0.4f);
            var glass = MatLib.Lit(GlassC, 0.9f);

            // Body: black lower half, white upper half.
            Box(vis, "Lower Body", new Vector3(0f, 0.45f, 0f), new Vector3(1.66f, 0.3f, 4.22f), black);
            Box(vis, "Upper Body", new Vector3(0f, 0.74f, 0f), new Vector3(1.64f, 0.3f, 4.16f), white);
            Box(vis, "Hood Slope", new Vector3(0f, 0.86f, 1.45f), new Vector3(1.56f, 0.08f, 1.2f), white, Quaternion.Euler(-4f, 0f, 0f));
            Box(vis, "Cabin", new Vector3(0f, 1.12f, -0.35f), new Vector3(1.42f, 0.48f, 1.9f), glass);
            Box(vis, "Roof", new Vector3(0f, 1.38f, -0.45f), new Vector3(1.38f, 0.06f, 1.55f), black);
            Box(vis, "Front Bumper", new Vector3(0f, 0.42f, 2.12f), new Vector3(1.6f, 0.2f, 0.12f), black);
            Box(vis, "Rear Bumper", new Vector3(0f, 0.42f, -2.12f), new Vector3(1.6f, 0.2f, 0.12f), black);
            Box(vis, "Trunk Lip", new Vector3(0f, 0.92f, -1.95f), new Vector3(1.5f, 0.05f, 0.25f), black);

            var hl = MatLib.Emissive(Headlight, 2.5f);
            Box(vis, "Headlight L", new Vector3(-0.55f, 0.72f, 2.09f), new Vector3(0.38f, 0.12f, 0.06f), hl);
            Box(vis, "Headlight R", new Vector3(0.55f, 0.72f, 2.09f), new Vector3(0.38f, 0.12f, 0.06f), hl);

            var tailMat = MatLib.EmissiveInstance(new Color(1f, 0.08f, 0.05f), 1.3f);
            Box(vis, "Tail Light L", new Vector3(-0.52f, 0.74f, -2.1f), new Vector3(0.5f, 0.14f, 0.06f), tailMat);
            Box(vis, "Tail Light R", new Vector3(0.52f, 0.74f, -2.1f), new Vector3(0.5f, 0.14f, 0.06f), tailMat);

            // Wheels. Front ones sit under pivots so they can steer.
            var tire = MatLib.Lit(Tire, 0.1f);
            var wheelScale = new Vector3(0.62f, 0.11f, 0.62f);
            var wheelRot = Quaternion.Euler(0f, 0f, 90f);
            Transform Pivot(string n, Vector3 p)
            {
                var t = new GameObject(n).transform;
                t.SetParent(vis, false);
                t.localPosition = p;
                Prim(PrimitiveType.Cylinder, t, "Wheel", Vector3.zero, wheelScale, tire, wheelRot);
                return t;
            }
            var fl = Pivot("Front Left", new Vector3(-0.74f, 0.31f, car.frontAxleZ));
            var fr = Pivot("Front Right", new Vector3(0.74f, 0.31f, car.frontAxleZ));
            Pivot("Rear Left", new Vector3(-0.74f, 0.31f, car.rearAxleZ));
            Pivot("Rear Right", new Vector3(0.74f, 0.31f, car.rearAxleZ));

            // Warm halogen headlight beam, to contrast with the cold LED street lights.
            var beamGo = new GameObject("Headlight Beam");
            beamGo.transform.SetParent(go.transform, false);
            beamGo.transform.localPosition = new Vector3(0f, 0.8f, 2.2f);
            beamGo.transform.localRotation = Quaternion.Euler(10f, 0f, 0f);
            var beam = beamGo.AddComponent<Light>();
            beam.type = LightType.Spot;
            beam.range = 30f;
            beam.spotAngle = 70f;
            beam.intensity = 3.5f;
            beam.color = new Color(1f, 0.92f, 0.78f);
            beam.shadows = LightShadows.None;
            beam.renderMode = LightRenderMode.ForcePixel;

            // Effects
            var fx = go.AddComponent<CarEffects>();
            fx.car = car;
            fx.frontLeftPivot = fl;
            fx.frontRightPivot = fr;
            fx.tailLights = tailMat;
            fx.skids = new[]
            {
                MakeSkid(go.transform, new Vector3(-0.74f, 0.02f, car.rearAxleZ)),
                MakeSkid(go.transform, new Vector3(0.74f, 0.02f, car.rearAxleZ)),
            };
            var smoke = new Color(0.78f, 0.78f, 0.82f, 0.28f);
            fx.tireSmoke = new[]
            {
                MakeSmoke(go.transform, new Vector3(-0.8f, 0.3f, car.rearAxleZ), smoke, 2.2f),
                MakeSmoke(go.transform, new Vector3(0.8f, 0.3f, car.rearAxleZ), smoke, 2.2f),
            };
            fx.engineSmoke = MakeSmoke(go.transform, new Vector3(0f, 1f, 1.6f), new Color(0.25f, 0.25f, 0.27f, 0.5f), 1.6f);

            return car;
        }

        static TrailRenderer MakeSkid(Transform parent, Vector3 localPos)
        {
            var go = new GameObject("Skid");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = Quaternion.Euler(-90f, 0f, 0f); // local Z points up, so the mark lies flat

            var tr = go.AddComponent<TrailRenderer>();
            tr.alignment = LineAlignment.TransformZ;
            tr.time = 25f;
            tr.minVertexDistance = 0.25f;
            tr.widthMultiplier = 0.24f;
            tr.numCapVertices = 0;
            tr.autodestruct = false;
            tr.emitting = false;
            tr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            tr.receiveShadows = false;
            tr.sharedMaterial = MatLib.Glow(new Color(0.02f, 0.02f, 0.02f, 0.6f), false);
            return tr;
        }

        static ParticleSystem MakeSmoke(Transform parent, Vector3 localPos, Color color, float size)
        {
            var go = new GameObject("Smoke");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;

            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);

            var main = ps.main;
            main.loop = true;
            main.duration = 1f;
            main.startLifetime = new ParticleSystem.MinMaxCurve(1.2f, 2.2f);
            main.startSpeed = new ParticleSystem.MinMaxCurve(0.3f, 1.2f);
            main.startSize = new ParticleSystem.MinMaxCurve(size * 0.6f, size);
            main.startColor = color;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = 400;
            main.gravityModifier = -0.03f;

            var em = ps.emission;
            em.rateOverTime = 0f;

            var shape = ps.shape;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = 0.25f;

            var sol = ps.sizeOverLifetime;
            sol.enabled = true;
            sol.size = new ParticleSystem.MinMaxCurve(1f, AnimationCurve.Linear(0f, 0.5f, 1f, 1.8f));

            var col = ps.colorOverLifetime;
            col.enabled = true;
            var g = new Gradient();
            g.SetKeys(
                new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                new[] { new GradientAlphaKey(1f, 0f), new GradientAlphaKey(0f, 1f) });
            col.color = g;

            var r = go.GetComponent<ParticleSystemRenderer>();
            r.sharedMaterial = MatLib.Glow(Color.white, true);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;

            ps.Play();
            return ps;
        }
    }
}
