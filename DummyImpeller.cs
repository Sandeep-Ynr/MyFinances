using System;
using System.IO;

class Program {
    static void Main(string[] args) {
        foreach (var arg in args) {
            if (arg.StartsWith("--spirv=")) {
                string path = arg.Substring("--spirv=".Length).Trim('"', '\'');
                try {
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    File.WriteAllBytes(path, new byte[0]);
                } catch {}
            }
            if (arg.StartsWith("--sl=")) {
                string path = arg.Substring("--sl=".Length).Trim('"', '\'');
                try {
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    File.WriteAllBytes(path, new byte[0]);
                } catch {}
            }
        }
    }
}
