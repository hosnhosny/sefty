// lib/widgets/violation_card.dart

import 'package:flutter/material.dart';
import '../models/violation_model.dart';

class ViolationCard extends StatelessWidget {
  final ViolationModel violation;
  final VoidCallback? onTap;
  final bool showOfficer;

  const ViolationCard({
    super.key,
    required this.violation,
    this.onTap,
    this.showOfficer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: violation.isRedAlert
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Number + Severity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          violation.violationNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (violation.isRedAlert) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '3 إنذارات',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: violation.severityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: violation.severityColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      violation.severityLabel,
                      style: TextStyle(
                        color: violation.severityColor == Colors.black
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Employee Info
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      violation.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.badge, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${violation.employeeId} | ${violation.employeeDepartment}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Violation Type
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        violation.customType,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              if (violation.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  violation.details,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Footer: Date + Location + Officer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${violation.createdAt.day}/${violation.createdAt.month}/${violation.createdAt.year}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${violation.createdAt.hour.toString().padLeft(2, '0')}:${violation.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (violation.exportedToExcel)
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                ],
              ),

              if (showOfficer) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.security, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'سجّلها: ${violation.securityOfficerName}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],

              if (violation.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      violation.location,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],

              // Evidence indicators
              if (violation.evidenceUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_file, size: 14, color: Colors.blue.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '${violation.evidenceUrls.length} مرفق',
                      style: TextStyle(
                        color: Colors.blue.shade400,
                        fontSize: 12,
                      ),
                    ),
                    if (violation.videoEvidenceUrls.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.videocam,
                          size: 14, color: Colors.deepPurple.shade300),
                      const SizedBox(width: 4),
                      Text(
                        'يتضمن فيديو',
                        style: TextStyle(
                          color: Colors.deepPurple.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}