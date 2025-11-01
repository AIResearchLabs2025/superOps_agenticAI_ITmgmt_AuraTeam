# Diagram Viewing Guide
## How to View Process Flow Diagrams

---

## **Recommended Tools for Viewing Mermaid Diagrams**

### **1. Visual Studio Code (Recommended)**
- **Extension**: Install "Mermaid Preview" or "Markdown Preview Mermaid Support"
- **Steps**:
  1. Open `docs/Process_Flow_Diagrams.md` in VS Code
  2. Press `Ctrl+Shift+V` (Windows/Linux) or `Cmd+Shift+V` (Mac) for preview
  3. Diagrams will render automatically in the preview pane

### **2. GitHub/GitLab (Online)**
- **Direct Viewing**: GitHub and GitLab automatically render Mermaid diagrams
- **Steps**:
  1. Push the file to your repository
  2. View `docs/Process_Flow_Diagrams.md` directly in the web interface
  3. All diagrams will be rendered automatically

### **3. Mermaid Live Editor (Online)**
- **URL**: https://mermaid.live/
- **Steps**:
  1. Copy any diagram code from the markdown file
  2. Paste it into the Mermaid Live Editor
  3. View and export as PNG/SVG

### **4. Obsidian (Knowledge Management)**
- **Built-in Support**: Obsidian has native Mermaid support
- **Steps**:
  1. Open the markdown file in Obsidian
  2. Diagrams render automatically in preview mode

### **5. Typora (Markdown Editor)**
- **Built-in Support**: Typora renders Mermaid diagrams natively
- **Steps**:
  1. Open the file in Typora
  2. Diagrams appear automatically in the editor

---

## **Browser Extensions**

### **Chrome/Edge Extensions**
- **Markdown Viewer**: Renders markdown with Mermaid support
- **Mermaid Diagrams**: Specifically for Mermaid rendering

### **Firefox Extensions**
- **Markdown Viewer Webext**: Supports Mermaid diagrams

---

## **Command Line Tools**

### **Mermaid CLI**
```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Convert to PNG
mmdc -i Process_Flow_Diagrams.md -o diagrams.png

# Convert to SVG
mmdc -i Process_Flow_Diagrams.md -o diagrams.svg
```

---

## **Quick Setup for VS Code (Recommended)**

1. **Install Extension**:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search for "Mermaid Preview"
   - Install "Mermaid Preview" by vstirbu

2. **View Diagrams**:
   - Open `docs/Process_Flow_Diagrams.md`
   - Right-click in the editor
   - Select "Open Preview to the Side"
   - All diagrams will render beautifully!

---

## **Alternative: Static Image Exports**

If you prefer static images, I can also create PNG/SVG versions of all diagrams using the Mermaid CLI or online tools.
