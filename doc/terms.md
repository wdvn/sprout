# List of terms in this project

# GPU Buffer

```
a GPU Buffer is a block of memory allocated within the Video RAM (VRAM) 
of your graphics card to store specific data that the GPU needs to access quickly.
```

Not all buffers hold the same type of data.Depending on what you're doing(gaming,AI, or rendering), you'll encounter
these:

| Buffer Type             | What it stores                                                                            |
|-------------------------|-------------------------------------------------------------------------------------------|
| Vertex Buffer (VBO)     | The XYZ coordinates of points that make up 3D objects.                                    |
| Index Buffer (IBO)      | The "map" telling the GPU which points to connect to form triangles.                      |
| Frame Buffer            | The final image data that is currently being drawn or waiting to be sent to your monitor. |
| Constant/Uniform Buffer | Settings that stay the same for a while, like the position of the sun or camera settings. |
| Storage Buffer          | Large chunks of raw data used in complex tasks like physics simulations or AI training.   |

### How the Process Works

1. Allocation: The software (like a game engine) asks the GPU to set aside a specific amount of VRAM.
2. Transfer (Upload): The CPU sends the data over the PCIe bus into that reserved buffer.
3. Execution: The GPU reads directly from the buffer to perform calculations or draw pixels.
4. Synchronization: If the data needs to change (like a character moving), the CPU updates the buffer.