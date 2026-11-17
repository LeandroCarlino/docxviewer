using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

// Reemplaza el icono (RT_GROUP_ICON + RT_ICON) de un .exe ya compilado.
// Uso: SetIcon.exe archivo.exe archivo.ico
class SetIconApp
{
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr BeginUpdateResource(string pFileName, bool bDeleteExistingResources);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool UpdateResource(IntPtr hUpdate, IntPtr lpType, IntPtr lpName, ushort wLanguage, byte[] lpData, uint cbData);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool EndUpdateResource(IntPtr hUpdate, bool fDiscard);

    const int RT_ICON = 3;
    const int RT_GROUP_ICON = 14;

    static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("uso: SetIcon.exe archivo.exe archivo.ico");
            Environment.Exit(1);
        }

        string exePath = Path.GetFullPath(args[0]);
        byte[] ico = File.ReadAllBytes(args[1]);

        if (ico.Length < 6 || BitConverter.ToUInt16(ico, 2) != 1)
        {
            Console.Error.WriteLine("el archivo no es un .ico valido");
            Environment.Exit(2);
        }

        int count = BitConverter.ToUInt16(ico, 4);
        if (count == 0 || count > 64)
        {
            Console.Error.WriteLine("cantidad de imagenes no soportada");
            Environment.Exit(3);
        }

        IntPtr handle = BeginUpdateResource(exePath, false);
        if (handle == IntPtr.Zero)
        {
            Console.Error.WriteLine("BeginUpdateResource: " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
            Environment.Exit(4);
        }

        try
        {
            ushort lang = 0; // lenguaje neutro
            int groupSize = 6 + count * 14;
            byte[] group = new byte[groupSize];
            group[0] = 0; group[1] = 0;
            group[2] = 1; group[3] = 0;
            group[4] = (byte)(count & 0xFF);
            group[5] = (byte)((count >> 8) & 0xFF);

            for (int i = 0; i < count; i++)
            {
                int off = 6 + i * 16;
                byte w = ico[off];
                byte h = ico[off + 1];
                byte colors = ico[off + 2];
                byte reserved = ico[off + 3];
                ushort planes = BitConverter.ToUInt16(ico, off + 4);
                ushort bits = BitConverter.ToUInt16(ico, off + 6);
                int size = BitConverter.ToInt32(ico, off + 8);
                int imgOff = BitConverter.ToInt32(ico, off + 12);

                if (size <= 0 || imgOff < 0 || imgOff + size > ico.Length) continue;

                byte[] data = new byte[size];
                Array.Copy(ico, imgOff, data, 0, size);

                if (!UpdateResource(handle, (IntPtr)RT_ICON, (IntPtr)(i + 1), lang, data, (uint)size))
                    throw new Win32Exception(Marshal.GetLastWin32Error());

                int g = 6 + i * 14;
                group[g] = w;
                group[g + 1] = h;
                group[g + 2] = colors;
                group[g + 3] = reserved;
                group[g + 4] = (byte)(planes & 0xFF);
                group[g + 5] = (byte)((planes >> 8) & 0xFF);
                group[g + 6] = (byte)(bits & 0xFF);
                group[g + 7] = (byte)((bits >> 8) & 0xFF);
                group[g + 8] = (byte)(size & 0xFF);
                group[g + 9] = (byte)((size >> 8) & 0xFF);
                group[g + 10] = (byte)((size >> 16) & 0xFF);
                group[g + 11] = (byte)((size >> 24) & 0xFF);
                group[g + 12] = (byte)((i + 1) & 0xFF);
                group[g + 13] = (byte)(((i + 1) >> 8) & 0xFF);
            }

            if (!UpdateResource(handle, (IntPtr)RT_GROUP_ICON, (IntPtr)1, lang, group, (uint)groupSize))
                throw new Win32Exception(Marshal.GetLastWin32Error());

            if (!EndUpdateResource(handle, false))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        catch (Exception ex)
        {
            EndUpdateResource(handle, true);
            Console.Error.WriteLine("SetIcon: " + ex.Message);
            Environment.Exit(5);
        }

        Console.WriteLine("icono actualizado en " + Path.GetFileName(exePath));
    }
}
