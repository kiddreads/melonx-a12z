using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Ryujinx.HLE.Generators
{
    [Generator]
    public sealed class TamperGenerator : IIncrementalGenerator
    {
        public void Initialize(IncrementalGeneratorInitializationContext context)
        {
            IncrementalValuesProvider<INamedTypeSymbol> operations =
                context.SyntaxProvider.CreateSyntaxProvider(
                    predicate: (node, _) =>
                    {
                        if (node is ClassDeclarationSyntax classDecl && classDecl.BaseList != null)
                        {
                            return classDecl.BaseList.Types.Any(t => t.Type.ToString().Equals("IOperation"));
                        }
                        return false;
                    },
                    transform: (ctx, _) => (INamedTypeSymbol)ctx.SemanticModel.GetDeclaredSymbol((ClassDeclarationSyntax)ctx.Node)
                ).Where(symbol => symbol != null);

            context.RegisterSourceOutput(operations.Collect(),
                (ctx, operationsData) =>
                {
                    var sourceBuilder = new StringBuilder();

                    sourceBuilder.AppendLine("#nullable enable");
                    sourceBuilder.AppendLine("using System;");
                    sourceBuilder.AppendLine("using Ryujinx.HLE.HOS.Tamper.Operations;");
                    sourceBuilder.AppendLine("using Ryujinx.HLE.HOS.Tamper.Conditions;");
                    sourceBuilder.AppendLine();
                    sourceBuilder.AppendLine("namespace Ryujinx.HLE.HOS.Tamper");
                    sourceBuilder.AppendLine("{");
                    sourceBuilder.AppendLine("    public static class TamperOperationFactory");
                    sourceBuilder.AppendLine("    {");

                    HashSet<string> generatedMethods = new HashSet<string>();

                    foreach (var operation in operationsData)
                    {
                        string methodName = operation.Name;

                        if (generatedMethods.Contains(methodName))
                            continue;

                        if (operation.IsGenericType)
                        {
                            GenerateGenericFactoryMethod(sourceBuilder, operation);
                        }
                        else
                        {
                            GenerateNonGenericFactoryMethod(sourceBuilder, operation);
                        }

                        generatedMethods.Add(methodName);
                    }

                    GenerateMainFactoryMethod(sourceBuilder, operationsData);

                    sourceBuilder.AppendLine("    }");
                    sourceBuilder.AppendLine("}");

                    ctx.AddSource("GeneratedOperations.g.cs", sourceBuilder.ToString());
                });
        }

        private void GenerateGenericFactoryMethod(StringBuilder sb, INamedTypeSymbol operationType)
        {
            string className = operationType.Name;
            
            var constructor = operationType.Constructors
                .FirstOrDefault(c => !c.IsStatic && c.DeclaredAccessibility == Accessibility.Public);

            if (constructor == null)
                return;

            var parameters = constructor.Parameters;
            
            sb.AppendLine($"        public static object Create{className}<T>(byte width, params object[] operands)");
            sb.AppendLine("        {");
            
            var paramCasts = new List<string>();
            for (int i = 0; i < parameters.Length; i++)
            {
                string cast = GetParameterCast(parameters[i], i);
                paramCasts.Add(cast);
            }
            
            string paramList = string.Join(", ", paramCasts);
            
            sb.AppendLine("            return width switch");
            sb.AppendLine("            {");
            sb.AppendLine($"                1 => new {className}<byte>({paramList}),");
            sb.AppendLine($"                2 => new {className}<ushort>({paramList}),");
            sb.AppendLine($"                4 => new {className}<uint>({paramList}),");
            sb.AppendLine($"                8 => new {className}<ulong>({paramList}),");
            sb.AppendLine("                _ => throw new ArgumentException($\"Invalid width: {width}\")");
            sb.AppendLine("            };");
            sb.AppendLine("        }");
            sb.AppendLine();
        }

        private void GenerateNonGenericFactoryMethod(StringBuilder sb, INamedTypeSymbol operationType)
        {
            string className = operationType.Name;
            
            var constructor = operationType.Constructors
                .FirstOrDefault(c => !c.IsStatic && c.DeclaredAccessibility == Accessibility.Public);

            if (constructor == null)
                return;

            var parameters = constructor.Parameters;
            
            sb.AppendLine($"        public static object Create{className}(byte width, params object[] operands)");
            sb.AppendLine("        {");
            
            var paramCasts = new List<string>();
            for (int i = 0; i < parameters.Length; i++)
            {
                string cast = GetParameterCast(parameters[i], i);
                paramCasts.Add(cast);
            }
            
            string paramList = string.Join(", ", paramCasts);
            
            sb.AppendLine($"            return new {className}({paramList});");
            sb.AppendLine("        }");
            sb.AppendLine();
        }

        private string GetParameterCast(IParameterSymbol parameter, int index)
        {
            string typeName = parameter.Type.ToDisplayString();
            
            if (typeName.Contains("IOperand"))
            {
                return $"(IOperand)operands[{index}]";
            }
            else if (typeName.Contains("ICondition"))
            {
                return $"(ICondition)operands[{index}]";
            }
            else if (typeName.Contains("IEnumerable<") && typeName.Contains("IOperation"))
            {
                return $"(System.Collections.Generic.IEnumerable<IOperation>)operands[{index}]";
            }
            else if (typeName == "bool")
            {
                return $"(bool)operands[{index}]";
            }
            else if (typeName == "int")
            {
                return $"(int)operands[{index}]";
            }
            else if (typeName == "byte")
            {
                return $"(byte)operands[{index}]";
            }
            else if (typeName == "ulong")
            {
                return $"(ulong)operands[{index}]";
            }
            else if (typeName.Contains("Register"))
            {
                return $"(Register)operands[{index}]";
            }
            else if (typeName.Contains("ITamperedProcess"))
            {
                return $"(ITamperedProcess)operands[{index}]";
            }
            else
            {
                // fallback :3
                return $"({typeName})operands[{index}]";
            }
        }

        private void GenerateMainFactoryMethod(StringBuilder sb, IEnumerable<INamedTypeSymbol> operationsData)
        {
            sb.AppendLine("        public static object Create(Type instruction, byte width, params object[] operands)");
            sb.AppendLine("        {");

            bool first = true;
            foreach (var operation in operationsData)
            {
                string className = operation.Name;
                string conditional = first ? "if" : "else if";
                first = false;

                if (operation.IsGenericType)
                {
                    sb.AppendLine($"            {conditional} (instruction.IsGenericType && instruction.GetGenericTypeDefinition() == typeof({className}<>))");
                    sb.AppendLine("            {");
                    sb.AppendLine($"                return Create{className}<object>(width, operands);");
                    sb.AppendLine("            }");
                }
                else
                {
                    sb.AppendLine($"            {conditional} (instruction == typeof({className}))");
                    sb.AppendLine("            {");
                    sb.AppendLine($"                return Create{className}(width, operands);");
                    sb.AppendLine("            }");
                }
            }

            sb.AppendLine("            else");
            sb.AppendLine("            {");
            sb.AppendLine("                throw new ArgumentException($\"Unsupported instruction type: {instruction.Name}\");");
            sb.AppendLine("            }");
            sb.AppendLine("        }");
        }
    }
}