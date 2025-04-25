# F.R.E.Y.A. — Fast Rendering Engine for Your Adventures

Welcome to F.R.E.Y.A., a rendering engine project built with Odin lang.

## Prerequisites

Before you can build or run F.R.E.Y.A., you need the following software installed on your system:

- **[Odin lang](https://odin-lang.org/):** `dev-2025-04` version or compatible.
- **[GLFW3](https://www.glfw.org/):** A multi-platform library for OpenGL, OpenGL ES, and Vulkan development.
- **[OpenGL 4.5](https://www.opengl.org/):** Ensure your graphics card drivers support OpenGL 4.5 or higher.
- **[Assimp (Open Asset Import Library)](https://assimp.org/):** A library to load various 3D model formats.
- **Git:** For cloning the repository.
- **Git LFS (Large File Storage):** For handling large asset files stored in the repository.

_(Installation methods vary by operating system. Use your system's package manager like `apt`, `brew`, `pacman`, `choco`, etc., or follow the official installation guides.)_

## Getting Started

You have two options to get F.R.E.Y.A. running: using a pre-built release or building it from the source code.

### Option 1: Using a Pre-built Release (Recommended)

1.  Navigate to the [Releases page](https://github.com/bytemomo/freya/releases) of this repository.
2.  Download the latest release archive suitable for your operating system.
3.  Extract the archive.
4.  Run the `animagik` executable found inside the extracted folder.

If a release isn't available for your system, or if it doesn't function correctly, proceed to build it from the source code.

### Option 2: Building from Source

Follow these steps if you prefer or need to build the project yourself.

**1. Clone the Repository**

```bash
git clone https://github.com/bytemomo/freya.git

cd freya
```

**2. Fetch Dependencies (LFS Assets & Submodules)**

```bash
git lfs pull
git submodule update --init --recursive
```

_This command downloads required large assets and initializes necessary library submodules._

**3. Compile the Project**

Create a build directory:

```bash
mkdir -p build/
```

You can compile using either `just` (a command runner) or the `odin` compiler directly.

- **Using `just`:**

    ```bash
    # Build release version
    just build

    # Build debug version
    just build-dbg
    ```

- **Using `odin` directly:**

    ```bash
    # Build release version -> build/animagik
    odin build animagik -out:build/animagik

    # Build debug version -> build/animagik-dbg
    odin build animagik -out:build/animagik-dbg -debug
    ```

**4. Run the Application**

Execute the compiled binary from the project's root directory:

- **For the release build:**

    ```bash
    ./build/animagik
    ```

- **For the debug build:**
    ```bash
    ./build/animagik-dbg
    ```
