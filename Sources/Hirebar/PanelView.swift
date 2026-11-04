import HirebarCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: PanelModel

    private struct AgentSection: Identifiable {
        let id: String
        let kinds: [AgentKind]
    }

    private let sections = [
        AgentSection(id: "Buscar trabajo", kinds: [.jobs, .freelance]),
        AgentSection(id: "Conseguir clientes", kinds: [.clients, .content]),
        AgentSection(id: "Tú", kinds: [.profile, .analyst]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.id.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            ForEach(model.agents.filter { section.kinds.contains($0.id) }) { agent in
                                AgentCard(agent: agent, model: model)
                            }
                        }
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 560)
            Divider()
            footer
        }
        .frame(width: 400)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.gradient)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hirebar").font(.system(size: 15, weight: .bold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.claudeBusy ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text("Claude: \(model.claude)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Label(model.telegram, systemImage: "paperplane.fill")
                .font(.caption)
                .foregroundStyle(model.telegramReady ? Color.blue : Color.secondary)
                .labelStyle(.titleAndIcon)
        }
        .padding(14)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(symbol: "doc.text.magnifyingglass", title: "Informes") { model.open(Paths.reports) }
            FooterButton(symbol: "list.bullet.rectangle", title: "Registro") { model.openLog() }
            FooterButton(symbol: "folder", title: "Datos") { model.open(Paths.root) }
            Spacer()
            Menu {
                Button("Configurar bot de Telegram…") { model.onConfigureTelegram?() }
                Button("Enviar aviso de prueba") { model.onSendTest?() }
                Button("Volver a vincular el chat") { model.onForgetChat?() }
                Divider()
                Toggle("Abrir al iniciar sesión", isOn: Binding(get: { model.opensAtLogin }, set: { _ in model.toggleLogin() }))
                Divider()
                Button("Salir de Hirebar") { model.onQuit?() }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct FooterButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

struct AgentCard: View {
    let agent: AgentCardData
    @ObservedObject var model: PanelModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AgentStyle.tint(agent.id).gradient)
                Image(systemName: AgentStyle.symbol(agent.id))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .saturation(agent.enabled ? 1 : 0)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(agent.name).font(.system(size: 13, weight: .semibold))
                    StatusPill(agent: agent)
                    Spacer()
                    Toggle("", isOn: Binding(get: { agent.enabled }, set: { _ in model.toggleEnabled(agent.id) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                }
                Text(agent.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !agent.stats.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(agent.stats, id: \.self) { stat in
                            Text(stat)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AgentStyle.tint(agent.id).opacity(0.12)))
                        }
                    }
                    .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Label(agent.next, systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if agent.canAutoApprove {
                        Toggle("Automático", isOn: Binding(get: { agent.autoApprove }, set: { _ in model.toggleAutoApprove(agent.id) }))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10))
                            .disabled(!agent.enabled)
                    }
                    Button(agent.id == .profile ? "Regenerar HV" : "Correr ahora") { model.runNow(agent.id) }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10, weight: .medium))
                        .disabled(!agent.enabled)
                    Menu {
                        if !agent.sources.isEmpty {
                            Section("Portales") {
                                ForEach(agent.sources) { source in
                                    Toggle(source.title, isOn: Binding(get: { source.on }, set: { _ in model.toggleSource(source.id) }))
                                }
                            }
                        }
                        if !agent.schedule.isEmpty {
                            Section("Horario") {
                                ForEach(agent.schedule, id: \.self) { line in Text(line) }
                            }
                        }
                        Button("Editar configuración…") { model.editSettings(agent.id) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(agent.working ? AgentStyle.tint(agent.id) : Color.primary.opacity(0.08), lineWidth: agent.working ? 1.5 : 1)
        )
        .opacity(agent.enabled ? 1 : 0.65)
    }
}

struct StatusPill: View {
    let agent: AgentCardData

    private var text: String {
        if !agent.enabled { return "Apagado" }
        if agent.working { return "Trabajando" }
        return "Activo"
    }

    private var color: Color {
        if !agent.enabled { return .gray }
        if agent.working { return .orange }
        return .green
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
